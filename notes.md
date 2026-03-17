# Introduction
This file contains various considerations I have during the development of the project. They are here just to keep track of what I am thinking at the moment.

## Register G
Register `G` is a flag register, i.e. its size is just 1 bit and is used for checking possible properties after an instruction (e.g. an overflow after an addition). 

I have not found no clear indication on when `G` is stored. I think it is in the Arithmetic Unit, since it is mostly used for checking exceptions occurred after an operation executed by it.

For this reason as of now `G` is part of the Arithmetic Unit.

## The Absolute Value operation
Some instruction consists of a binary operation between two numbers, one of the two whose has been reduced to its absolute value. This computation is considered a middle step. 

An absolute value operation has always just one operand.

The absolute value is obtained as a repeated negation over the requested number, until the flag register `G` detects an overflow (i.e. is set to one). An overflow in a negation means that the obtained number has as most significant bit zero, i.e. the number has been made positive.

This operation always causes an overflow, since it is detected by checking that the overflow has been set! This value is useless, since the absolute value of a number is always computed as a middle-step for an arithmetic binary operation, thus at the end of the instruction, register `G` has been rewritten. Still, we have preferred to activate the overflow regardless.

Pseudocode:
``` C
Abs_value (A: register) {
    while (G != 1) Negate (A);
}
```

## Register content management
- Registers must contain un-interpreted sequences of bits. 
- These sequences are concretelly implemented as unsigned integers, but are interpreted as int/float/so on depending on the type of operation applied to them.
- When printing the content of the registers for debug reasons, they are always printed as binary sequences.

## Notation
I will follow the Zig official style guide:

```
- If x is a struct with 0 fields and is never meant to be instantiated then x is considered to be a "namespace" and should be snake_case.
   
- If x is a type or type alias then x should be TitleCase.

- If x is callable, and x's return type is type, then x should be TitleCase.

- If x is otherwise callable, then x should be camelCase.

- Otherwise, x should be snake_case.
```
