# Southern Cross SC-1 Z80 SBC

## Southern Cross Monitor — Version 1.9 Release Notes

## Release Date: 2026-08-04

## Summary

Adds increased functionality to the SCBUG serial monitor including the addition of a disassembler.
Made the full features of the serial monitor available while single stepping.

Monitor tidy up. Removed the conditional assembly for the TEC-1F and some other additional
conditional code to make the source code simpler to read. Reformatted the comments.
Added auto-increment to data entry, advancing the address automatically when entering bytes using the keyboard.

## Compatibility Notes

Memory allocated to the monitor from the top of RAM has been reduced.
System calls remain identical to all previous monitor releases, some additional system calls added.
Some improvements to the way  restart vectors and interrupts are handled.

## Optimizations & Bug Fixes

PRINTSZ prints the terminating zero. Fixed.
PRINTSZ renamed as ILPSZ (In-Line Print String Zero terminated)


## Southern Cross Monitor — Version 1.91 Release Notes

## Release Date: 2026-09-01

## Summary
The hardware single stepper generates an interrupt after the instruction has been executed, if 
the executed instruction is in ROM then the interrupt is inhibited by the hardware(we don't want the debug 
monitor to step through itself).
This means that, when single stepping, the first instruction after coming back from a ROM routine is
not shown.
## Compatibility Notes

## Optimizations & Bug Fixes
The GO command in SCBug has been changed to allow the first instruction to be shown when single-stepping
is started. 
