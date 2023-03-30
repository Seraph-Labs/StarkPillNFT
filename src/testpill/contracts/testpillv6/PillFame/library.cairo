%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin, SignatureBuiltin, BitwiseBuiltin
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.bool import TRUE, FALSE
from starkware.cairo.common.uint256 import Uint256, uint256_check, uint256_eq, uint256_le
from starkware.cairo.common.math import assert_not_zero, assert_not_equal
from starkware.starknet.common.syscalls import get_caller_address, get_contract_address
from starkware.cairo.common.math_cmp import is_not_zero, is_le
from openzeppelin.security.safemath.library import SafeUint256
// ------------------------------- token libs ------------------------------- //
from SeraphLabs.tokens.ERC2114.library import (
    ERC2114_createAttribute,
    _ERC2114_addAttribute,
    _ERC2114_attributeAmmount,
)
// ERC2114 storage variables
from SeraphLabs.tokens.ERC2114.library import (
    ERC2114_tokenAttribute_len,
    ERC2114_tokenAttribute_value,
)
from SeraphLabs.tokens.ERC3525.library import ERC3525_slotOf
// ------------------------------- interfaces ------------------------------- //
from testpill.interfaces.IVotingBooth import IVotingBooth
// --------------------------------- models --------------------------------- //
from SeraphLabs.models.StringObject import StrObj
from SeraphLabs.tokens.erc2114.libs.scalarToken import TokenAttr
// -------------------------------- constants ------------------------------- //
from testpill.utils.pillConstants.library import ATTR4, ATTR5

// -------------------------------------------------------------------------- //
//                                   events                                   //
// -------------------------------------------------------------------------- //
@event
func PillFameUpdated(voter: felt, tokenId: Uint256, fame: felt) {
}

@event
func PillDeFameUpdated(voter: felt, tokenId: Uint256, defame: felt) {
}
// -------------------------------------------------------------------------- //
//                                   storage                                  //
// -------------------------------------------------------------------------- //

@storage_var
func starkpill_voting_booth_contract() -> (address: felt) {
}

namespace PillFame {
    // -------------------------------------------------------------------------- //
    //                                 constructor                                //
    // -------------------------------------------------------------------------- //

    func initializer{syscall_ptr: felt*, range_check_ptr, pedersen_ptr: HashBuiltin*}() {
        ERC2114_createAttribute(Uint256(4, 0), StrObj(ATTR4, 6));
        ERC2114_createAttribute(Uint256(5, 0), StrObj(ATTR5, 8));
        return ();
    }

    // -------------------------------------------------------------------------- //
    //                                 view funcs                                 //
    // -------------------------------------------------------------------------- //
    func getVotingBoothContract{syscall_ptr: felt*, range_check_ptr, pedersen_ptr: HashBuiltin*}(
        ) -> (address: felt) {
        let (address) = starkpill_voting_booth_contract.read();
        return (address,);
    }

    func getPillFameLevels{
        bitwise_ptr: BitwiseBuiltin*,
        syscall_ptr: felt*,
        range_check_ptr,
        pedersen_ptr: HashBuiltin*,
    }(tokenId: Uint256) -> (fame: felt, defame: felt) {
        alloc_locals;
        // check if tokenId is of type pill;
        let (pill_slot: Uint256) = ERC3525_slotOf(tokenId);
        with_attr error_message("starkpill: tokenId must be of type pill") {
            let (is_pill) = uint256_eq(pill_slot, Uint256(1, 0));
            assert is_pill = TRUE;
        }
        let (fame: Uint256, defame: Uint256) = _get_pill_fame(tokenId);
        return (fame.low, defame.low);
    }
    // -------------------------------------------------------------------------- //
    //                                  externals                                 //
    // -------------------------------------------------------------------------- //

    func famePill{
        bitwise_ptr: BitwiseBuiltin*,
        syscall_ptr: felt*,
        range_check_ptr,
        pedersen_ptr: HashBuiltin*,
    }(tokenId: Uint256, ammount: felt) {
        alloc_locals;
        let (caller) = get_caller_address();
        with_attr error_message("starkpill: caller is invalid") {
            assert_not_zero(caller);
        }

        let (votingbooth_addr) = starkpill_voting_booth_contract.read();
        with_attr error_message("starkpill: voting booth contract has not been initialized") {
            assert_not_zero(votingbooth_addr);
        }

        // check if caller can vote with votingbooth contract
        IVotingBooth.execute_votes(votingbooth_addr, caller, ammount);

        // change pill fame
        let (new_fame) = _update_pill_fame_levels(tokenId, Uint256(4, 0), ammount);
        // emit event
        PillFameUpdated.emit(caller, tokenId, new_fame);
        return ();
    }

    func deFamePill{
        bitwise_ptr: BitwiseBuiltin*,
        syscall_ptr: felt*,
        range_check_ptr,
        pedersen_ptr: HashBuiltin*,
    }(tokenId: Uint256, ammount: felt) {
        alloc_locals;
        let (caller) = get_caller_address();
        with_attr error_message("starkpill: caller is invalid") {
            assert_not_zero(caller);
        }

        let (votingbooth_addr) = starkpill_voting_booth_contract.read();
        with_attr error_message("starkpill: voting booth contract has not been initialized") {
            assert_not_zero(votingbooth_addr);
        }

        // check if caller can vote with votingbooth contract
        IVotingBooth.execute_votes(votingbooth_addr, caller, ammount);

        // change pill fame
        let (new_fame) = _update_pill_fame_levels(tokenId, Uint256(5, 0), ammount);
        // emit event
        PillDeFameUpdated.emit(caller, tokenId, new_fame);
        return ();
    }

    func setVotingBoothContract{syscall_ptr: felt*, range_check_ptr, pedersen_ptr: HashBuiltin*}(
        address: felt
    ) {
        with_attr error_message("starkpill: address is invalid") {
            assert_not_zero(address);
        }

        starkpill_voting_booth_contract.write(address);
        return ();
    }
}
// -------------------------------------------------------------------------- //
//                                  internals                                 //
// -------------------------------------------------------------------------- //

// checks if tokenId has attribute if they dont
// add attribute, if they do change the storage variable to update ammount
// returns new ammount for attribute
func _update_pill_fame_levels{
    bitwise_ptr: BitwiseBuiltin*, syscall_ptr: felt*, range_check_ptr, pedersen_ptr: HashBuiltin*
}(tokenId: Uint256, attrId: Uint256, ammount: felt) -> (new_ammount: felt) {
    alloc_locals;
    // check if tokenId is of type pill;
    let (pill_slot: Uint256) = ERC3525_slotOf(tokenId);
    with_attr error_message("starkpill: tokenId must be of type pill") {
        let (is_pill) = uint256_eq(pill_slot, Uint256(1, 0));
        assert is_pill = TRUE;
    }

    // ensure ammount is valid
    with_attr error_message("starkpill: invalid attr ammount") {
        let not_valid = is_le(ammount, 0);
        assert not_valid = FALSE;
    }

    let (local attrObj: TokenAttr) = ERC2114_tokenAttribute_value.read(tokenId, attrId);
    let (no_attr) = uint256_le(attrObj.ammount, Uint256(0, 0));
    // if no attribute add attribute
    if (no_attr == TRUE) {
        // add attribute to cur_len index
        let (cur_len) = ERC2114_tokenAttribute_len.read(tokenId);
        _ERC2114_addAttribute(
            tokenId=tokenId,
            attrId=attrId,
            value=attrObj.value,
            ammount=Uint256(ammount, 0),
            index=cur_len,
        );
        // increase length
        tempvar new_len = cur_len + 1;
        ERC2114_tokenAttribute_len.write(tokenId, new_len);
        return (ammount,);
    } else {
        // get new attribute ammount
        let (new_attr_ammt: Uint256) = SafeUint256.add(attrObj.ammount, Uint256(ammount, 0));
        // update attribute ammount
        ERC2114_tokenAttribute_value.write(
            tokenId, attrId, TokenAttr(attrObj.value, new_attr_ammt)
        );
        return (new_attr_ammt.low,);
    }
}

// assumes tokenId is pill
func _get_pill_fame{syscall_ptr: felt*, range_check_ptr, pedersen_ptr: HashBuiltin*}(
    tokenId: Uint256
) -> (fame: Uint256, defame: Uint256) {
    let (fame: Uint256) = _ERC2114_attributeAmmount(tokenId, Uint256(4, 0));
    let (defame: Uint256) = _ERC2114_attributeAmmount(tokenId, Uint256(5, 0));
    return (fame, defame);
}
