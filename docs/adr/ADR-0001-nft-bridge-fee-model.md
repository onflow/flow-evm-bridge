# NFT Bridge Fee Collection Applies Only to Storage-Consuming Operations

- **Status:** Accepted
- **Date:** 2026-03-11
- **Decision-makers:** Joshua, Jan
- **Consulted:** dete (original bridge designer)
- **Informed:** Flow Foundation team

---

## Context and Problem Statement

Feedback received via the bug bounty program identified that four NFT handler functions in `FlowEVMBridge.cdc` accept a `feeProvider` parameter but never call `FlowEVMBridgeUtils.depositFee()` on it:

| Handler | Direction | Action |
|---------|-----------|--------|
| `handleUpdatedBridgedNFTToEVM` | Cadence → EVM | burn (`FlowEVMBridge.cdc:L933`) |
| `handleCadenceNativeCrossVMNFTFromEVM` | EVM → Cadence | return from escrow (`FlowEVMBridge.cdc:L1089`) |
| `handleEVMNativeCrossVMNFTFromEVM` | EVM → Cadence | return from escrow or mint (`FlowEVMBridge.cdc:L1133–L1139`) |
| `handleUpdatedBridgedNFTFromEVM` | EVM → Cadence | return from escrow or mint (`FlowEVMBridge.cdc:L1185–L1189`) |

All three cross-VM FromEVM handlers and the updated-bridged ToEVM handler silently skip fee collection, while equivalent handlers on the ToEVM cross-VM path (`handleCadenceNativeCrossVMNFTToEVM`, `handleEVMNativeCrossVMNFTToEVM`) do charge fees. The omission was confirmed with Cadence tests measuring bridge account balance before and after each operation.

The flow-evm-bridge repository's `README.md` (hereafter README) states: *"In all cases, there is a flat-rate fee in addition to any storage fees."* This raised the question of whether the missing fee calls are a bug (revenue loss) or a documentation inaccuracy (the fee model is narrower than stated). FLIP #237, the original bridge design document (superseded by FLIP #318), describes `baseFee` as a flat-rate charge applied to every bridge request — lending support to the interpretation that the missing fee calls were an unintentional omission.

## Decision Drivers

- The bridge fee must be grounded in a concrete cost borne by the bridge, not be an arbitrary service charge.
- Computation costs are already covered by native Flow network transaction fees charged to the caller — no additional bridge-level fee for computation is warranted.
- When Cadence code calls EVM, no EVM gas is collected from the bridge COA; the caller's computation effort covers the cost.
- The bridge has a resource-drain risk for operations that cause it to **store** assets long-term (escrowed Cadence NFTs occupy the bridge account's storage).
- The implementation must remain simple and easy for developers to integrate against.
- Documentation must accurately reflect actual behavior.
- FLIP #318 (which superseded FLIP #237) describes `baseFee` as applying to storage-consuming operations; the four affected handlers are an acknowledged inconsistency with even this updated spec, and the team must decide whether to correct the code or accept and document the deviation.

## Considered Options

1. **Centralize fee collection in NFT entry points** — add `calculateBridgeFee` + `depositFee` to `bridgeNFTToEVM` and `bridgeNFTFromEVM` before any handler dispatch, matching the FT bridge pattern.
2. **Add fee logic to each affected handler individually** — insert the two missing lines into each of the four handlers.
3. **Update documentation to reflect the actual (storage-only) fee model** — no code changes; correct README to remove the incorrect "flat-rate fee in all cases" claim.

## Decision Outcome

**Chosen option: Update documentation (Option 3).**

The four handlers in question either burn the NFT (no escrow), release a pre-escrowed NFT (escrow already paid for on deposit), or mint/unlock on the Cadence side without adding to bridge storage. None of them cause the bridge to incur new long-term storage costs, so charging a fee for them would be collecting money with no corresponding cost justification.

This is an acknowledged inconsistency with the broader specification, as confirmed by a project contributor in [GitHub issue #200](https://github.com/onflow/flow-evm-bridge/issues/200). However, since none of the four handlers consume bridge account storage, the team determined it does not pose a security risk and that correcting the code to charge fees where no storage cost exists would be economically unjustified. The decision is to accept the inconsistency and correct the documentation to match actual behaviour.

This decision constitutes a deliberate deviation from FLIP #318 (which superseded FLIP #237). Following consultation with the original bridge designer, the team concluded that fees were always meant to cover concrete costs borne by the bridge — primarily storage of escrowed assets — and that the FLIP descriptions did not fully anticipate the cross-VM NFT handler pattern introduced later.

This satisfies the decision drivers that the fee must be grounded in a concrete cost borne by the bridge, that documentation must accurately reflect actual behavior, and that the implementation must remain simple and easy for developers to integrate against.

The `feeProvider` parameter in the affected handlers is an artifact of the delegated fee-passing pattern used throughout the NFT dispatch chain. Its presence does not imply an obligation to charge a fee — it is passed through so that handlers _can_ charge if their logic warrants it.

The README claim that *"In all cases, there is a flat-rate fee"* predates the cross-VM NFT bridging pattern and is incorrect. It must be updated to accurately describe the fee model.

### Consequences

- Good: no code change required — while the existing behaviour is an acknowledged inconsistency with the broader spec, it does not pose a security risk and charging fees where no storage is consumed would be unjustified.
- Good: removes a misleading README claim that overstated fee obligations, reducing integration confusion.
- Good: the fee model remains simple and principled (fees = storage costs only).
- Bad: the `feeProvider` parameter in handlers that never charge a fee is slightly misleading; a future refactor could remove it from handlers that provably will never use it, but this is not required now.
- Bad: projects that integrated expecting zero fees on cross-VM paths already benefit from the current behavior; this decision formally enshrines it, so any future decision to add fees here would be a breaking change.

### Confirmation

- README is updated to remove the "flat-rate fee in all cases" statement and to clarify that fees are charged only when the bridge operation causes the bridge account to store an asset.
- Code in the four handlers is left unchanged.
- Existing test suite for the four handlers passes without modification.

## Pros and Cons of the Options

### Option 1: Centralize fee collection in NFT entry points

Mirror the FT bridge pattern: collect `baseFee` in `bridgeNFTToEVM` / `bridgeNFTFromEVM` before dispatching to any handler.

- Good, because it eliminates handler-by-handler omission risk — new handlers automatically pay the fee.
- Good, because it matches the FT bridge architecture for consistency.
- Bad, because it charges a fee with no cost justification for operations where the bridge stores nothing.
- Bad, because `baseFee` could be zero, making the change a no-op in production if the fee is not set — giving false confidence without real enforcement.
- Bad, because it introduces a breaking behavioral change to cross-VM NFT bridging that all integrated projects would need to account for.

### Option 2: Add fee logic to each affected handler individually

Insert `calculateBridgeFee` + `depositFee` into the four handlers.

- Good, because it is surgical and does not change the dispatch architecture.
- Bad, because it preserves the delegated pattern that caused the omission in the first place — future new handlers remain potential fee-bypass vectors.
- Bad, because, like Option 1, it charges a fee that has no cost justification for these specific operations.

### Option 3: Update documentation (chosen)

Correct README to accurately describe the storage-based fee model; leave code unchanged.

- Good, because it aligns documentation with actual behavior without imposing unjustified fees.
- Good, because it preserves the cost-based fee rationale established at bridge design time.
- Good, because it requires the smallest change (docs only) with zero risk of regressions.
- Bad, because the `feeProvider` parameter in handlers that never use it remains a minor source of confusion.

## More Information

- **Origin:** Feedback received via the bug bounty program.
- **Original design:** [FLIP #237](https://github.com/onflow/flips/blob/main/application/20231222-evm-vm-bridge.md) — the original bridge design document, superseded by FLIP #318. Describes `baseFee` as a flat-rate charge on every bridge request.
- **Updated design:** FLIP #318 — supersedes FLIP #237 and should be considered the authoritative spec alongside this ADR.
- **GitHub issue #200:** https://github.com/onflow/flow-evm-bridge/issues/200 — public discussion thread where a project contributor acknowledged the inconsistency and confirmed it is not a security concern since the affected handlers do not consume bridge account storage.
- **Affected contract:** `cadence/contracts/bridge/FlowEVMBridge.cdc`
- **Inaccurate documentation:** README line 80 — *"In all cases, there is a flat-rate fee in addition to any storage fees."*
- **Fee mechanism:** `FlowEVMBridgeUtils.calculateBridgeFee(bytes: N)` computes the fee based on bytes to be stored; `FlowEVMBridgeUtils.depositFee(feeProvider, feeAmount)` withdraws from the caller's vault into the bridge account. `baseFee` is an admin-configurable floor stored in `FlowEVMBridgeConfig`.
- **Handlers that correctly charge fees (control cases):** `handleDefaultNFTToEVM` and `handleDefaultNFTFromEVM` both call `depositFee` because they escrow NFTs into bridge-held storage. `handleCadenceNativeCrossVMNFTToEVM` and `handleEVMNativeCrossVMNFTToEVM` charge fees via `escrowNFTAndWithdrawFee` for the same reason.
