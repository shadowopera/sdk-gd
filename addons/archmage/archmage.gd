## The entry point of the Archmage SDK and its only global class name.
##
## Other SDK scripts have no [code]class_name[/code]. This script attaches them as constants,
## so code refers to them as [code]Archmage.Duration[/code] without a [code]preload[/code].
class_name Archmage
extends RefCounted

## The version of the SDK.
const VERSION := "0.1.0"
