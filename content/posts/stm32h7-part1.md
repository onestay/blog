+++
date = '2026-03-12T21:25:19+01:00'
draft = true
title = 'STM32F7 bare-metal development Part 0'
tags = ["Embedded", "STM32"]
+++

I've been interested in embedded development for some time.
In the past I have done simple ESP32 projects and played around with [ESPHome](https://esphome.io/).

## Reintroduction to embedded

This was quite some time ago
but recently my interest in embedded development has been revived
after listening to the fantastic [Oxide and Friends](https://oxide-and-friends.transistor.fm/) podcast from [0xide Computers](https://oxide.computer/).
I'm not quite sure what episode it was but in the episode they were talking about STM32 MCUs.

As one does nowadays I asked Claude for recommendations on how to get started on STM32 boards.
It recommended me a [NUCLEO-F767ZI](https://www.st.com/en/evaluation-tools/nucleo-f767zi.html) which for a beginner might not be the best option.
But not knowing better I went to my online retailer of choice I purchased one for 33,20€.
Nucleo boards in general are quite nice devkits and include an ST-Link debugger which can be used for other boards as well.

The STM32F767ZI is quite the complicated MCU.
With a clock speed of up to 216 MHz, 2MB of flash and 512 KB of flash it is quite a beast in the MCU world.
It also includes all kinds of fancy peripherals half of which I don't even know what they do.

## First Steps

After receiving the board I unboxed it and was immediately surprised by it's size.
So far I'm used to ESP32 dev boards which are quite small but here the MCU itself is roughly the size of half an ESP32 dev board.

I've heard ST has excellent documentation so I downloaded the datasheet and was quite surprised.
It was only about 150 pages and I honestly expected more.
I already knew some basics about memory mapped IO, so I expected to write some C code to write some value into some register and have an LED blink.
Nowhere in the datasheet I could find any info about GPIO registers.

I went to the documentation section of my MCU had no idea where to start.
There were specifications, application notes, technical notes, manuals.
After downloading various documents that sounded interesting and useful I found the reference manual.
Clocking in at 1942 pages this seemed like the correct document.
There even was a section on GPIO, perfect!
Now I just need to write into the register... wait what is all this?
`GPIOx_MODER`, `GPIOx_OTYPER`, `GPIOx_PUPDR`...
okay clearly this method won't work.
A reference manual is obviously not a tutorial and should not be used if you have no clue what you are doing.
I generally like going by manuals and documentation but I'm missing some quite fundamental knowledge to use this document.

## Second steps

I clearly needed some kind of tutorial.
Simply googling for STM32 tutorial didn't get me far.
Most guides or blogs use some kind of HAL or other abstraction layer.
However before using `digitalWrite(15, 1)` I want to build it up from scratch.

I'm always deeply curious about the "lower layer".
At the start of my programming journey I've never been satisfied with clicking the "Run & Compile" button.
I always needed to know how it works below, what actually happens and this carries over to this embedded journey I was embarking on.
A lot of resources were telling me that it's unproductive to go this route and not how it's done in practice but that didn't really matter to me.
I'm fine using an IDE or a HAL but only after I understood the bottom layer.
Other bare metal resources just dumped a bunch of code at me without explanation or assumed stuff I didn't know yet.

Once I went from looking for STM32 specific guides to just ARM or even only bare metal programming guides I've stumbled upon [cpq/bare-metal-programming-guide](https://github.com/cpq/bare-metal-programming-guide).
This seemed to be exactly what I was looking for and perfectly aimed at my knowledge level.
