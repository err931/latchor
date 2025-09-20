# Latchor Development Log

## Introduction

To all readers: This log clearly shows the use of AI (LLM) in the software
development process. If you strongly oppose AI (LLM) involvement, I recommend
stopping here.

## That's why

This section explains why I decided to build a Tang-compatible implementation in
Elixir. The main reasons are these three points.

- The Tang protocol spec is very simple, so it's possible to create a fully
  compatible implementation without using a full-stack framework.
- I expected to gain more practical experience than just following the Phoenix
  Framework tutorials.
- Developing a blog engine or task management system wouldn't benefit anyone,
  including me. These areas are already oversaturated, with almost no real
  demand.

At first, I thought creating a compatible implementation of the Tang protocol
would be tough. But after reviewing the protocol spec, I became confident that
even with just six months of Elixir experience, I could do it.

Of course, all the documentation for Tang and its Tang protocol components is in
English, which is a big challenge for me as a Japanese speaker. However, that
challenge itself is one reason why I thought it was worth tackling.

## THE LATCHOR CONCEPT

For this Tang-compatible implementation, I set two rules for myself.

- Do not add extensions beyond what Tang already implements; stick only to the
  features in the original Tang spec.
- However, change the server-side key management from file-based to
  SQLite-based.

The second rule was especially important. File-based key management has the
advantage of leaving access control entirely to the OS. But the spec for key
rotation—adding a dot to the old key file name— isn't the most robust approach.

There is a script for key rotation, but it doesn't delete old keys. To delete
old keys, users have to manually handle files, which risks accidentally deleting
the key pair still in use.

So, I thought a safer way is to store two key pairs (JWKs) in one record and
delete the whole record when it's no longer needed.

The name "Latchor" is a made-up word from brainstorming with an LLM. Clevis
means a U-shaped connector with holes at both ends for bolts or pins. From that
idea of a "connector to latch onto," I came up with the name.

In the early development, I called the software "Tengu," but I dropped it
because it didn't connect well to Clevis.

## Main Module Structure

- **Latchor.Keyring** — The core module. It manages key generation, retrieval,
  deletion, and everything else.
- **Latchor.Keyring.KeyExchange** — Implements the key exchange (ECDH) protocol.
- **Latchor.Keyring.RecoveryJWKValidator** — Validates the recovery JWK sent
  from the client.
- **Latchor.Keyring.Schema** — Defines the schema for the key management table
  and handles converting generated JWKs for database storage.
- **Latchor.Router** — Implements routing for API endpoints.

## Testing Strategy and Validation Method

For a Tang-compatible implementation, it has to be recognized as a Tang pin
server by Clevis—otherwise, it's pointless. So, I first set up a validation
method using Clevis.

```bash
echo "Lorem Ipsum" | clevis encrypt tang '{"url":"http://localhost"}' > secret.txt
clevis decrypt < secret.txt
```

If this round trip restores the original string, it's working correctly as a
Tang pin server.

## Why Only ECDH Uses an External CLI

### Overview of the Recovery Flow

In Tang's recovery, it uses a special ECDH-derived algorithm called the
McCallum–Relyea exchange. This is regular ECDH plus adding an ephemeral key to
the public key (binding).

### Technical Hurdle

Erlang/OTP's standard `:crypto` module and `erlang-jose` don't cover the
low-level OpenSSL functions needed for this addition (like `EC_POINT_add`). So,
it was hard to do it all in Elixir alone.

### Options Considered

- **Custom NIF Implementation** — Reduces external dependencies but requires
  C-language coding and maintenance, plus security risks.
- **External CLI Call** — Increases process startup costs and external
  dependencies, but allows using the same `jose` CLI as Tang.

### Reason for Choice

In the end, I chose the port method using the same CLI as Tang. It ensures
compatibility and safety, and the structure allows swapping it out later if a
library supports it.

## Ignoring Trust Boundaries: Unnecessary "Helpful" Code Generation

In Latchor, external inputs (JWK from Clevis) and internal generations (JWK from
`erlang-jose`) have different trust levels. We always validate external inputs,
but internal ones are guaranteed by the dependency library, so extra validation
isn't needed.

However, when I asked an LLM to implement the schema,

- It applied strict validation for external inputs to internal data too.
- It added unnecessary formatting and type conversions before saving.
- As a result, even correct data failed to save.

This is a classic case where the LLM didn't understand the difference in
processing phases ("validate then format and save") and applied the same
safe-side treatment to both. In AI-assisted development like vibe coding, this
kind of "overly helpful" code sneaks in easily.

In the end, I rewrote about half the generated code to get back to a simple
implementation that fits the goal:

- Minimal type checks.
- Automatic generation of kid (thumbprint).
- Guaranteed order in Map conversions.

From this, I learned that LLMs can produce syntactically correct code but don't
understand domain-specific assumptions like **what can be trusted**. Especially
with crypto keys, over-validation can cause problems instead.

## Conclusion

You might wonder why I'm putting this development log in the repository. I know
it's more common to post on Medium, dev.to, or a personal blog.

But please understand that this log **isn't meant for wide public sharing**.

In reality, development logs like this aren't read much unless they're in
popular languages like TypeScript or Rust. And Elixir—which powers much of
Discord's core but most people don't even notice— is even less so.

So, this log is written for the **limited people who are interested enough to
access this repo and check the README or source code in detail**.

In minor languages, you can't rely much on LLM help. So, most of the code has to
come from your own skills.

But by using AI (LLM) to parse docs, identify needed external modules, and
reflect that in your code, I believe you can steadily improve your programming
skills.

I hope this log gives you a push forward in your programming. And please, try
challenging yourself with the Elixir programming language.

If you can handle higher-order functions like `map()` or `filter()` in Python 3,
learning Elixir shouldn't be too hard.
