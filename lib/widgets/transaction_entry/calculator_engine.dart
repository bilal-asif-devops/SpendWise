class CalculatorEngine {
  String _expression = "0";
  String? _errorMessage;

  String get expression => _expression;
  String? get errorMessage => _errorMessage;

  bool get hasPendingOperation {
    return _expression.contains('+') ||
        _expression.contains('-') ||
        _expression.contains('×') ||
        _expression.contains('÷');
  }

  void clear() {
    _expression = "0";
    _errorMessage = null;
  }

  void setAmount(double amount) {
    if (!amount.isFinite || amount.isNaN || amount <= 0) {
      _expression = "0";
    } else if (amount == amount.truncateToDouble()) {
      _expression = amount.toInt().toString();
    } else {
      _expression = amount.toStringAsFixed(2);
    }
    _errorMessage = null;
  }

  void inputDigit(String digit) {
    _errorMessage = null;
    if (_expression == "0" || _expression == "0.00") {
      _expression = digit;
      return;
    }

    // Check decimal places for current operand
    final currentOperand = _getCurrentOperand();
    if (currentOperand.contains('.')) {
      final parts = currentOperand.split('.');
      if (parts.length > 1 && parts[1].length >= 2) {
        // Limit to 2 decimal digits for transaction entry
        return;
      }
    }

    _expression += digit;
  }

  void inputDecimal() {
    _errorMessage = null;
    final currentOperand = _getCurrentOperand();
    if (currentOperand.isEmpty) {
      _expression += "0.";
      return;
    }
    if (currentOperand.contains('.')) {
      return; // Already has decimal point in current operand
    }
    _expression += ".";
  }

  void inputOperator(String op) {
    _errorMessage = null;
    if (_expression.isEmpty) {
      _expression = "0";
    }

    final trimmed = _expression.trim();
    final lastChar = trimmed[trimmed.length - 1];

    if (_isOperator(lastChar)) {
      // Replace operator
      _expression = "${trimmed.substring(0, trimmed.length - 1).trim()} $op ";
      return;
    }

    // If there is already a complete binary expression, evaluate it first
    if (hasPendingOperation) {
      final evaluated = evaluate();
      if (!evaluated) return; // Error occurred
    }

    _expression = "${_expression.trim()} $op ";
  }

  void backspace() {
    _errorMessage = null;
    final trimmed = _expression.trim();
    if (trimmed.length <= 1 || trimmed == "0") {
      _expression = "0";
      return;
    }

    // If last token was an operator with spaces, strip the operator
    if (trimmed.endsWith('+') ||
        trimmed.endsWith('-') ||
        trimmed.endsWith('×') ||
        trimmed.endsWith('÷')) {
      _expression = trimmed.substring(0, trimmed.length - 1).trim();
      return;
    }

    _expression = trimmed.substring(0, trimmed.length - 1);
    if (_expression.isEmpty) {
      _expression = "0";
    }
  }

  bool evaluate() {
    _errorMessage = null;
    final trimmed = _expression.trim();
    if (!hasPendingOperation) {
      final val = double.tryParse(trimmed);
      if (val != null && val.isFinite && !val.isNaN) {
        _expression = _formatNumber(val);
        return true;
      }
      return true;
    }

    try {
      final tokens = trimmed.split(RegExp(r'\s+'));
      if (tokens.isEmpty) {
        _expression = "0";
        return true;
      }

      if (tokens.length == 1) {
        final val = double.tryParse(tokens[0]);
        if (val != null && val.isFinite && !val.isNaN) {
          _expression = _formatNumber(val);
          return true;
        }
        return true;
      }

      // Parse tokens [num1, op, num2, ...]
      double result = double.tryParse(tokens[0]) ?? 0.0;
      for (int i = 1; i < tokens.length; i += 2) {
        if (i + 1 >= tokens.length) {
          // Incomplete trailing operator (e.g. "12 + ")
          break;
        }
        final op = tokens[i];
        final nextNum = double.tryParse(tokens[i + 1]);
        if (nextNum == null) continue;

        switch (op) {
          case '+':
            result += nextNum;
            break;
          case '-':
            result -= nextNum;
            break;
          case '×':
          case '*':
            result *= nextNum;
            break;
          case '÷':
          case '/':
            if (nextNum == 0) {
              _errorMessage = "Cannot divide by zero";
              return false;
            }
            result /= nextNum;
            break;
        }
      }

      if (!result.isFinite || result.isNaN) {
        _errorMessage = "Invalid calculation result";
        return false;
      }

      _expression = _formatNumber(result);
      return true;
    } catch (e) {
      _errorMessage = "Invalid expression";
      return false;
    }
  }

  double? getNumericAmount() {
    evaluate();
    if (_errorMessage != null) return null;
    final val = double.tryParse(_expression.trim());
    if (val == null || !val.isFinite || val.isNaN || val <= 0) {
      return null;
    }
    return val;
  }

  String _getCurrentOperand() {
    final tokens = _expression.trim().split(RegExp(r'\s+'));
    if (tokens.isEmpty) return "";
    final last = tokens.last;
    if (_isOperator(last)) return "";
    return last;
  }

  bool _isOperator(String ch) {
    return ch == '+' ||
        ch == '-' ||
        ch == '×' ||
        ch == '*' ||
        ch == '÷' ||
        ch == '/';
  }

  String _formatNumber(double val) {
    if (val == val.truncateToDouble()) {
      return val.toInt().toString();
    }
    return double.parse(val.toStringAsFixed(2)).toString();
  }
}
