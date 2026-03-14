+++
date = '2026-03-11T21:23:31+01:00'
draft = false
title = 'Personal Kicad Library Convention (KLC)'
tags = ["kicad"]
+++

Personal Kicad library conventions for symbol libraries.
Inspired by the [official KiCad Library Convention (KLC)](https://klc.kicad.org/) but adapted for a fully specified component library.

## 1. Scope

These conventions apply to all symbol libraries prefixed with `MyLib_`.
Every symbol in these libraries should be fully specified.
It represents one exact purchasable component with a pre-assigned footprint, datasheet, and distributor information.

## 2. Library Naming

Libraries are named by function using the format:

```
MyLib_<Function>
```

Use singular nouns and CamelCase for multi-word functions.

| Library Name              | Contents                          |
|---------------------------|-----------------------------------|
| `MyLib_Capacitor`         | All capacitor types               |
| `MyLib_Resistor`          | Resistors, including arrays       |
| `MyLib_Inductor`          | Inductors, ferrite beads          |
| `MyLib_Diode`             | Diodes, TVS, Zener, Schottky, LEDs     |
| `MyLib_IC_Power`          | Voltage regulators, charge ICs    |
| `MyLib_MCU`               | Microcontrollers                  |
| `MyLib_Connector`         | Various connectors (FFC, Pin Headers)               |
| `MyLib_Sensor`            | Temperature, IMU, pressure, etc.  |
| `MyLib_Oscillator`        | Crystals, oscillators, resonators |

## 3. Symbol Naming

Symbols follow the format:

```
<RefDes>_<Value>_<Package>_<Manufacturer>_<MPN>
```

### 3.1 Field Definitions

| Field            | Description                                           | Examples                    |
|------------------|-------------------------------------------------------|-----------------------------|
| `<RefDes>`       | Standard reference designator prefix                  | `C`, `R`, `L`, `U`, `D`, `Q`, `J`, `Y` |
| `<Value>`        | Human-readable electrical value or function            | `100nF`, `10k`, `3.3V-LDO` |
| `<Package>`      | Package identifier                              | `0402`, `0603`, `SOT-23`, `SOIC-8`, `QFN-32` |
| `<Manufacturer>` | Manufacturer name                          | `Murata`, `TI`, `ST`, `Nexperia` |
| `<MPN>`          | Manufacturer part number   | `GRM155R71C104KA88`         |

### 3.2 Examples

| Symbol Name                                       | Library              |
|---------------------------------------------------|----------------------|
| `C_100nF_0402_Murata_GRM155R71C104KA88`           | `MyLib_Capacitor`    |
| `R_10k_0603_Yageo_RC0603FR-0710KL`               | `MyLib_Resistor`     |
| `U_3.3V-LDO_SOT-23-5_TI_TLV75533PDBV`           | `MyLib_IC_Power`     |
| `U_STM32F103C8_LQFP-48_ST_STM32F103C8T6`         | `MyLib_MCU`          |
| `D_Red_0603_Wurth_150060RS75000`                  | `MyLib_LED`          |
| `J_USB-C_Amphenol_12401610E4-2A`                  | `MyLib_Connector`    |

### 3.3 Special Cases

- **ICs where the value is essentially the part number:** Use a short functional description as the value instead of repeating the MPN. E.g. `U_3.3V-LDO_...` rather than `U_TLV75533_..._TI_TLV75533PDBV`.
- **Connectors:** Value can describe the function or pin count, e.g. `J_USB-C_...`, `J_2x5-SWD_...`.

## 4. Required Symbol Fields

Every symbol **must** contain the following fields.

### 4.1 Standard KiCad Fields

| Field         | Visibility | Content                                                      |
|---------------|------------|--------------------------------------------------------------|
| `Reference`   | Visible    | Standard RefDes (`C`, `R`, `U`, `D`, `Q`, `J`, `L`, etc.)    |
| `Value`       | Visible    | Symbol name (matches the full symbol name from Section 3)    |
| `Footprint`   | Hidden     | Full footprint path, e.g. `Capacitor_SMD:C_0402_1005Metric`  |
| `Datasheet`   | Hidden     | URL to the manufacturer datasheet (PDF link preferred)       |

### 4.2 Custom Fields

| Field                        | Visibility | Content                                                        |
|------------------------------|------------|----------------------------------------------------------------|
| `Manufacturer`               | Hidden     | Manufacturer name, e.g. `Murata`, `Texas Instruments`          |
| `Manufacturer Part Number`   | Hidden     | Exact orderable MPN, e.g. `GRM155R71C104KA88J`                 |
| `Distributor Link 1`         | Hidden     | URL to primary distributor product page                        |
| `Distributor 1 Part Number`  | Hidden     | Primary distributor's SKU, e.g. `490-16434-1-ND` (Digi-Key)    |
| `Distributor Link 2`         | Hidden     | URL to secondary distributor product page                       |
| `Distributor 2 Part Number`  | Hidden     | Secondary distributor's SKU, e.g. `81-GRM155R71C104KA8J` (Mouser) |

### 4.3 Field Notes

- The `Manufacturer Part Number` field contains the full, exact orderable MPN.
- Distributor fields enable one-click ordering and BOM export to purchasing tools.
- If only one distributor source is known, leave `Distributor Link 2` and `Distributor 2 Part Number` as `~`.
- All custom fields are hidden to keep the schematic clean.
- If possible download a PDF of the datasheet and host it on your own server/keep it locally.

## 5. Footprint Association

- Every symbol **must** have a default footprint assigned in the `Footprint` field.
- If the same component exists in multiple packages, create a separate symbol for each package.

## 6. General Rules

### 6.1 Characters

- Only use: `A-Z`, `a-z`, `0-9`, `_`, `-`, `.`, `,`, `+`
- No spaces in symbol or library names.

### 6.2 Symbol Graphics

- Whenever possible derive symbols from the Kicad library.
- When creation of a custom symbol or footprint is necessary, follow the official KLC for pin placement, outline style, and text sizes.
- Consider upstreaming the generic variant of the component to the Kicad library.

### 6.3 Adding a New Part — Checklist

Before a symbol is considered complete, verify:

- [ ] Symbol name follows `<RefDes>_<Value>_<Package>_<Manufacturer>_<MPN>` format
- [ ] Symbol is placed in the correct `MyLib_<Function>` library
- [ ] `Reference` field is correct and visible
- [ ] `Value` field matches symbol name and is visible
- [ ] `Footprint` field points to a valid footprint and is hidden
- [ ] `Datasheet` field contains a working URL and is hidden
- [ ] `Manufacturer` field is filled and hidden
- [ ] `Manufacturer Part Number` field is filled and hidden
- [ ] `Distributor Link 1` and `Distributor 1 Part Number` are filled and hidden
- [ ] `Distributor Link 2` and `Distributor 2 Part Number` are filled (or set to `~`) and hidden
- [ ] Footprint filters are set
- [ ] Symbol has been visually checked in the symbol editor

---

## 7. Revision History

| Version | Date       | Notes            |
|---------|------------|------------------|
| 1.0     | 2026-03-14 | Initial release  |
