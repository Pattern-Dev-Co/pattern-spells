// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import { SpellRunner }           from "./SpellRunner.sol";
import { CommonSpellAssertions } from "./CommonSpellAssertions.sol";
import { CommonTestBase }        from "./CommonTestBase.sol";

/// @dev Convenience contract meant to be the single point of entry for spell-specific test contracts.
abstract contract SkybaseTestBase is SpellRunner, CommonSpellAssertions, CommonTestBase {
}
