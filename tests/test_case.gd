## The base class of test scripts.
##
## GDScript has no exceptions, and [code]assert[/code] is stripped from release exports,
## so a test reports a failure by calling [method check] or [method check_eq].
## A test is a method named [code]test_*[/code]; it may use [code]await[/code].
extends RefCounted

## The failure messages recorded by the current test. The test passes when it is empty.
var failures: Array[String] = []


## Records a failure with [param message] when [param condition] is false.
func check(condition: bool, message: String = "check failed") -> void:
	if not condition:
		failures.append(message)


## Records a failure when [param actual] is not equal to [param expected].
func check_eq(actual: Variant, expected: Variant, message: String = "") -> void:
	if typeof(actual) != typeof(expected) or actual != expected:
		failures.append("%sexpected %s, got %s" % [message + ": " if message != "" else "", var_to_str(expected), var_to_str(actual)])


## True while [method capture_errors] is active.
var capturing := false
## The error messages captured since [method capture_errors].
var captured: Array[String] = []


## Starts capturing script and engine errors, such as [code]push_error[/code], instead of failing the test.
## Call [method take_errors] to stop and read them. Without capture, any error fails the test.
func capture_errors() -> void:
	capturing = true
	captured = []


## Stops capturing and returns the captured error messages.
func take_errors() -> Array[String]:
	capturing = false
	var result := captured
	captured = []
	return result
