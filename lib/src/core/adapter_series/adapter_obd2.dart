import 'dart:async';
import 'dart:convert';
import 'package:math_expressions/math_expressions.dart';
import '../../../obd2.dart';

/// AT = Attention Command (ELM327 prefix)
/// ECU = Engine Control Unit
/// PID = Parameter Identifier
/// SAE = Society of Automotive Engineers
/// J1979 = OBD-II emissions diagnostic standard
/// CAN = Controller Area Network

/// Core low-level SAE J1979 OBD-II adapter engine.
///
/// This abstract class provides:
///
/// - Transport lifecycle control
/// - ELM327 initialization
/// - Concurrency-safe command execution
/// - Service-mode execution (Mode 03, 04, 07, 0A)
/// - PID-mode execution (Mode 01, 02, 09)
/// - ASCII response buffering
/// - Formula evaluation
/// - Composite PID parsing
///
/// Concrete transport layers (Bluetooth, WiFi, USB)
/// must extend this class and implement physical I/O behavior.
///
/// This class separates:
/// - Service-level commands
/// - PID-level commands
///
/// ensuring architectural correctness and extensibility.
abstract class AdapterOBD2 {

  late final SaeJ1979 protocol;

  bool get isConnected;

  Stream<List<int>> get incomingData;

  Future<void> write(List<int> data);

  Future<void> disconnect();

  bool _isInitializingAdapter = false;

  /// Prevents overlapping requests.
  bool _isRequestInProgress = false;

  /// Accumulates fragmented ASCII responses.
  String _responseBuffer = '';

  /// Completer for active request.
  Completer<String>? _pendingResponseCompleter;

  AdapterOBD2() {
    protocol = SaeJ1979(this);
    incomingData.listen(_handleIncomingData);
  }

  /// Initializes the ELM327 adapter.
  ///
  /// Executes:
  /// - ATZ
  /// - ATE0
  /// - ATL0
  /// - ATSP0
  ///
  /// ### Returns:
  /// - (`Future<void>`): Completes when initialization finishes.
  ///
  /// ### Throws:
  /// - (`StateError`): If adapter is not connected.
  Future<void> initializeAdapter() async {
    if (!isConnected) {
      throw StateError('Adapter is not connected.');
    }

    _isInitializingAdapter = true;

    try {
      await _executeRawCommand("ATZ");
      await Future.delayed(const Duration(milliseconds: 1000));

      const List<String> setupCommands = ["ATE0", "ATL0", "ATSP0"];

      for (final String command in setupCommands) {
        await _executeRawCommand(command);
        await Future.delayed(const Duration(milliseconds: 250));
      }
    } finally {
      _isInitializingAdapter = false;
    }
  }

  /// Executes a service-level OBD command.
  ///
  /// Used for:
  /// - Mode 03
  /// - Mode 04
  /// - Mode 07
  /// - Mode 0A
  ///
  /// ### Parameters:
  /// - (`String`) serviceHex: Two-character service hex (e.g., "03").
  ///
  /// ### Returns:
  /// - (`Future<List<int>?>`): Payload bytes excluding service header.
  ///
  /// ### Throws:
  /// - (`StateError`): If adapter is not connected or busy.
  Future<List<int>?> sendService(String serviceHex) async {
    final String rawResponse = await _executeRawCommand(serviceHex);
    return _parseServiceResponse(rawResponse, serviceHex);
  }

  /// Executes a service command that requires a Parameter ID.
  ///
  /// Used for:
  /// - Mode 01
  /// - Mode 02
  /// - Mode 09
  ///
  /// ### Parameters:
  /// - (`String`) serviceHex: Service hex (e.g., "01").
  /// - (`String`) parameterIDHex: PID hex (e.g., "0C").
  ///
  /// ### Returns:
  /// - (`Future<List<int>?>`): Payload bytes.
  ///
  /// ### Throws:
  /// - (`StateError`): If adapter is not connected or busy.
  Future<List<int>?> sendServiceWithPID(String serviceHex, String parameterIDHex) async {
    final String command = "$serviceHex$parameterIDHex";
    final String rawResponse = await _executeRawCommand(command);

    return _parseServiceResponse(
      rawResponse,
      serviceHex,
      parameterIDHex: parameterIDHex,
    );  
  }

  /// Queries a DetailedPID using the service abstraction layer.
  ///
  /// This method:
  /// 1. Extracts service + PID from `parameterID`
  /// 2. Executes service-with-PID
  /// 3. Applies decoding logic
  ///
  /// ### Parameters:
  /// - (`DetailedPID`) detailedPID: PID metadata definition.
  ///
  /// ### Returns:
  /// - (`Future<dynamic>`): Decoded value or null.
  ///
  /// ### Throws:
  /// - (`StateError`): If adapter is initializing.
  Future<dynamic> queryPID(DetailedPID detailedPID) async {
    if (_isInitializingAdapter) {
      throw StateError("Cannot query while adapter is initializing.");
    }

    if (detailedPID.parameterID.length < 4) {
      throw ArgumentError("Invalid parameterID format.");
    }

    final String serviceHex = detailedPID.parameterID.substring(0, 2);
    final String parameterIDHex = detailedPID.parameterID.substring(2);

    final List<int>? dataBytes = await sendServiceWithPID(serviceHex, parameterIDHex);

    if (dataBytes == null || dataBytes.isEmpty) {
      return null;
    }

    switch (detailedPID.obd2QueryReturnType) {

      case QueryReturnValue.text:
        return String.fromCharCodes(dataBytes);

      case QueryReturnValue.status:
        return dataBytes;

      case QueryReturnValue.composite:
        return _parseCompositePID(detailedPID, dataBytes);

      case QueryReturnValue.double:
        return _evaluateMathExpression(detailedPID, dataBytes);
    }
  }

  /// Parses a raw OBD-II response into a list of bytes, with optional PID validation.
  ///
  /// This function processes multi-line responses from a vehicle interface. It identifies 
  /// the correct response line by checking for the expected service mode (Request + 0x40) 
  /// and, if provided, the specific Parameter Identifier (PID).
  ///
  /// ### Parameters
  /// - [rawResponse] (`String`): The multi-line string received from the OBD-II adapter.
  /// - [serviceHex] (`String`): The hexadecimal request service mode (e.g., "01").
  /// - [parameterIDHex] (`String?`): Optional hexadecimal PID to refine the search.
  ///
  /// ### Returns
  /// - (`List<int>?`): A list of data bytes extracted from the payload, or `null` if no match is found.
  ///
  /// ### Usage
  /// ```dart
  /// // General service response
  /// final data = _parseServiceResponse("41 0C 1A F8", "01");
  /// 
  /// // Specific PID response
  /// final dataPid = _parseServiceResponse("41 0C 1A F8", "01", parameterIDHex: "0C");
  /// ```
  List<int>? _parseServiceResponse(
    String rawResponse,
    String serviceHex, {
    String? parameterIDHex,
  }) {
    if (rawResponse.contains("NO DATA") == true) return null;

    // serviceHex: Service Hexadecimal (The request mode/service ID)
    // expectedResponseMode: The integer value of the mode plus the 0x40 response offset
    final int expectedResponseMode = int.parse(serviceHex, radix: 16) + 0x40;

    // expectedResponseHex: Expected Response Hexadecimal (The 2-char hex header string)
    final String expectedResponseHex = expectedResponseMode.toRadixString(16).toUpperCase();

    final List<String> lines = rawResponse
        .split(RegExp(r'[\r\n]+')) // Split input into discrete lines for processing
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty && line != '>') // Remove empty entries and terminal prompts
        .toList();

    String? validLine;

    /*
    * Iterates through the response lines to find a valid match. 
    * If a PID is provided, it validates the full header (Mode + PID).
    * Otherwise, it validates based on the Response Mode alone.
    */
    String? expectedFullHeader;

    if (parameterIDHex != null) {
      expectedFullHeader = "$expectedResponseHex$parameterIDHex";
    }

    for (final line in lines) {
      final cleaned = line.replaceAll(' ', '');

      if (expectedFullHeader != null) {
        if (cleaned.startsWith(expectedFullHeader)) {
          validLine = cleaned;
          break;
        }
      } else {
        if (cleaned.startsWith(expectedResponseHex)) {
          validLine = cleaned;
          break;
        }
      }
    }

    if (validLine == null) return null;
    final String cleaned = validLine.replaceAll(' ', ''); // Ensure no spaces exist in the target line

    // payloadHex: Payload Hexadecimal (The raw data portion of the string)
    String payloadHex;

    /*
    * Calculates the starting index for the payload. If a PID was used in the 
    * header, the payload starts after both the mode and PID characters.
    */
    if (parameterIDHex != null) {
      payloadHex = cleaned.substring(expectedResponseHex.length + parameterIDHex.length);
    } else {
      payloadHex = cleaned.substring(expectedResponseHex.length);
    }

    final List<int> bytes = [];

    /*
    * Standard hex-to-byte conversion loop. It takes substrings of length 2 
    * and parses them as base-16 integers to populate the byte list.
    */
    for (int index = 0; index < payloadHex.length; index += 2) {
      if (index + 1 >= payloadHex.length) break;

      bytes.add(
        int.parse(
          payloadHex.substring(index, index + 2), // Extract 2 hex characters
          radix: 16,
        ),
      );
    }

    return bytes;
  }

  /// Evaluates mathematical expression defined in PID metadata.
  ///
  /// Byte placeholders `[0]`, `[1]`, etc. are replaced
  /// before parsing and evaluation.
  ///
  /// ### Parameters:
  /// - (`DetailedPID`) detailedPID: PID containing formula.
  /// - (`List<int>`) dataBytes: Raw ECU response bytes.
  ///
  /// ### Returns:
  /// - (`double?`): Evaluated numeric value or null.
  double? _evaluateMathExpression(DetailedPID detailedPID, List<int> dataBytes) {
    try {
      String formula = detailedPID.formula;

      for (int index = 0; index < dataBytes.length; index++) {
        formula = formula.replaceAll(
          '[$index]',
          dataBytes[index].toString(),
        );
      }

      final Expression expression =
      GrammarParser().parse(formula);

      return RealEvaluator(ContextModel())
          .evaluate(expression)
          .toDouble();

    } catch (_) {
      return null;
    }
  }

  /// Parses composite PID responses.
  ///
  /// ### Parameters:
  /// - (`DetailedPID`) detailedPID: PID metadata.
  /// - (`List<int>`) bytes: Raw data bytes.
  ///
  /// ### Returns:
  /// - (`List<double>?`): Composite values or null.
  List<double>? _parseCompositePID(DetailedPID detailedPID, List<int> bytes) {
    if (detailedPID.parameterID == "0124" && bytes.length >= 4) {
      return [
        (256.0 * bytes[0] + bytes[1]) / 32768.0,
        (256.0 * bytes[2] + bytes[3]) / 8192.0
      ];
    }

    return null;
  }

  /// Executes raw ASCII command and waits for completion.
  ///
  /// ### Parameters:
  /// - (`String`) command: ASCII hex command.
  ///
  /// ### Returns:
  /// - (`Future<String>`): Full ASCII response.
  ///
  /// ### Throws:
  /// - (`StateError`): If adapter not connected or busy.
  Future<String> _executeRawCommand(String command) async {
    if (!isConnected) {
      throw StateError('Adapter is not connected.');
    }

    if (_isRequestInProgress) {
      throw StateError('Another request is already in progress.');
    }

    _isRequestInProgress = true;
    _responseBuffer = '';
    _pendingResponseCompleter = Completer<String>();

    try {
      await write(utf8.encode('$command\r'));

      final String response = await _pendingResponseCompleter!.future.timeout(
        const Duration(seconds: 5)
      );

      return response;

    } finally {
      _isRequestInProgress = false;
      _pendingResponseCompleter = null;
    }
  }

  /// Handles fragmented incoming ASCII data.
  ///
  /// Completes the pending request once '>' prompt is detected.
  ///
  /// ### Parameters:
  /// - (`List<int>`) data: Incoming byte chunk.
  void _handleIncomingData(List<int> data) {
    final String newText = utf8.decode(data, allowMalformed: true);

    _responseBuffer += newText;

    if (_responseBuffer.trim().endsWith('>') == true) {
      if (_pendingResponseCompleter != null && !_pendingResponseCompleter!.isCompleted) {
        _pendingResponseCompleter!.complete(_responseBuffer);
      }
    }
  }
}