# Agensi distribution sources

These sources build an Agensi MCP edition of `coordinator-review-drive`. They are distribution inputs, not a
second installable skill in the public collection. The main `skills/coordinator-review-drive/` stays the local
installation edition.

Agensi's current documentation requires each supplied script to run unchanged from an individual temporary file,
without installed package siblings. The builder embeds common runner helpers and default policy data, creates a
standalone goal initializer, and omits the shared library and detached launcher. The coordinating host manages
worker/waiter background execution. The initializer produces fresh user project state, not a local skill copy.

Build into a new directory outside the source tree:

```bash
python3 scripts/build_agensi.py /absolute/path/to/agensi-package/coordinator-review-drive
```

Run `python3 -m unittest discover -s tests -v` before distributing. Tests use fake CLIs and temporary goal data.
They do not validate authenticated Agensi delivery, all live CLI versions, or native macOS enforcement.

Package the resulting directory as one ZIP for creator upload. Buyers access the listing through Agensi MCP;
do not describe it as a buyer ZIP download. The proposed price is US$5 once, as requested by the author.
Publishing also depends on access to the creator account, its configured payout method and platform review.

Official references, checked 2026-11-05:

- [Package your skill](https://www.agensi.io/docs/packaging)
- [How agents load skills](https://www.agensi.io/docs/how-agents-load-skills)
- [Website submission](https://www.agensi.io/docs/submit-on-the-website)
- [Pricing](https://www.agensi.io/docs/pricing-your-skill)

No additional license grant or support commitment is introduced by this distribution preparation.
