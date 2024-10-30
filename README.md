# BeraBook

[![Docs](https://img.shields.io/badge/docs-%F0%9F%93%84-blue)](https://docs.berabook.fun/)
[![CI status](https://github.com/BeraBook/core/actions/workflows/test.yaml/badge.svg)](https://github.com/berabook/core/actions/workflows/test.yaml)
[![Discord](https://img.shields.io/static/v1?logo=discord&label=discord&message=Join&color=blue)](https://discord.com/invite/bera-book)
[![Twitter](https://img.shields.io/static/v1?logo=twitter&label=twitter&message=Follow&color=blue)](https://x.com/BeraBook)

Core Contract of BeraBook DEX

## Table of Contents

- [BeraBook](#berabook)
    - [Table of Contents](#table-of-contents)
    - [Deployments](#deployments)
    - [Install](#install)
    - [Usage](#usage)
        - [Tests](#tests)
        - [Linting](#linting)
        - [Library](#library)
    - [Licensing](#licensing)

## Deployments

All deployments can be found in the [deployments](./deployments) directory.

## Install


### Prerequisites
- We use [Forge Foundry](https://github.com/foundry-rs/foundry) for test. Follow the [guide](https://github.com/foundry-rs/foundry#installation) to install Foundry.

### Installing From Source

```bash
git clone https://github.com/BeraBook/core && cd core
npm install
```

## Usage

### Tests
```bash
npm run test
```

### Linting

To run lint checks:
```bash
npm run prettier:ts
npm run lint:sol
```

To run lint fixes:
```bash
npm run prettier:fix:ts
npm run lint:fix:sol
```

### Library
To utilize the contracts, you can install the code in your repo with forge:
```bash
forge install https://github.com/BeraBook/core
```

## Licensing
- The primary license for BeraBook Core is the Time-delayed Open Source Software Licence, see [License file](LICENSE_V2.pdf).
- Interfaces are licensed under MIT (as indicated in their SPDX headers).
- Some [libraries](src/libraries) have a GPL license.
