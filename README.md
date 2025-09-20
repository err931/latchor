# Latchor

Tang-compatible NBDE server written in Elixir

> [!CAUTION]
> This project is an experimental implementation intended **only for research
> and learning purposes**. **Do not use in production environments.**

## Overview

Latchor is a Tang-compatible NBDE server written in Elixir. It aims to provide a
minimal and educational reference for understanding Tang protocol.

## Features

- Tang protocol compatibility
- SQLite-based keyring management

## Dependencies

- [jose](https://github.com/latchset/jose)
- Elixir v1.18 (OTP/27+)

## Usage

```bash
# Install dependencies
mix setup

# Run the server
mix run --no-halt
```

You can test it with [Clevis](https://github.com/latchset/clevis):

```bash
echo "Hello Latchor" | clevis encrypt tang '{"url":"http://localhost:37564"}' > secret.txt
clevis decrypt < secret.txt
```

## License

![GitHub License](https://img.shields.io/github/license/err931/latchor?style=for-the-badge)

## Authors

- [Minoru Maekawa](https://github.com/err931)
