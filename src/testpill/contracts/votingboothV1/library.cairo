%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin, SignatureBuiltin, BitwiseBuiltin
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.bool import TRUE, FALSE
from starkware.cairo.common.uint256 import Uint256, uint256_eq, uint256_le
from starkware.cairo.common.math import assert_not_zero
from starkware.starknet.common.syscalls import (
    get_caller_address,
    get_contract_address,
    get_block_timestamp,
)
from starkware.cairo.common.math_cmp import is_not_zero, is_le
from openzeppelin.security.safemath.library import SafeUint256

// ------------------------------- interfaces ------------------------------- //
from testpill.interfaces.ISPILL import ISPILL

// -------------------------------------------------------------------------- //
//                                   events                                   //
// -------------------------------------------------------------------------- //
@event
func PillVoteTimeStamp(tokenId: Uint256, time_stamp: felt) {
}

@event
func TraitVoteTimeStamp(pillId: Uint256, traitId: Uint256, time_stamp: felt) {
}

// -------------------------------------------------------------------------- //
//                                   storage                                  //
// -------------------------------------------------------------------------- //
@storage_var
func votingbooth_starkpill_contract() -> (contract_addr: felt) {
}

@storage_var
func votingbooth_lastvote(tokenId: Uint256) -> (time_stamp: felt) {
}

namespace VotingBooth {
    // -------------------------------------------------------------------------- //
    //                                 constructor                                //
    // -------------------------------------------------------------------------- //
    func initializer{syscall_ptr: felt*, range_check_ptr, pedersen_ptr: HashBuiltin*}(
        starkpill_contract: felt
    ) {
        votingbooth_starkpill_contract.write(starkpill_contract);
        return ();
    }

    // -------------------------------------------------------------------------- //
    //                                  view func                                 //
    // -------------------------------------------------------------------------- //

    func getOwnerVotes{
        bitwise_ptr: BitwiseBuiltin*,
        syscall_ptr: felt*,
        range_check_ptr,
        pedersen_ptr: HashBuiltin*,
    }(owner: felt) -> (ammount: felt) {
        alloc_locals;
        let (local spill_addr) = votingbooth_starkpill_contract.read();
        let (balance: Uint256) = ISPILL.balanceOf(spill_addr, owner);

        let (is_zero) = uint256_le(balance, Uint256(0, 0));
        if (is_zero == TRUE) {
            return (0,);
        }

        let (ammount) = _getOwnerVote_recursion(owner, spill_addr, Uint256(0, 0), balance, 0);
        return (ammount,);
    }

    func getPillVotingPower{
        bitwise_ptr: BitwiseBuiltin*,
        syscall_ptr: felt*,
        range_check_ptr,
        pedersen_ptr: HashBuiltin*,
    }(pillId: Uint256) -> (ammount: felt) {
        alloc_locals;
        let (local spill_addr) = votingbooth_starkpill_contract.read();

        let (slot: Uint256) = ISPILL.slotOf(spill_addr, pillId);
        let (is_pill) = uint256_eq(slot, Uint256(1, 0));
        if (is_pill == FALSE) {
            return (0,);
        }

        let (ammount) = _get_pill_voting_power(spill_addr, pillId);
        return (ammount,);
    }

    // get time diff between last_vote and current timeStamp
    func getPillVoteTimer{
        bitwise_ptr: BitwiseBuiltin*,
        syscall_ptr: felt*,
        range_check_ptr,
        pedersen_ptr: HashBuiltin*,
    }(pillId: Uint256) -> (time: felt) {
        alloc_locals;
        let (local spill_addr) = votingbooth_starkpill_contract.read();

        let (slot: Uint256) = ISPILL.slotOf(spill_addr, pillId);
        let (is_pill) = uint256_eq(slot, Uint256(1, 0));
        if (is_pill == FALSE) {
            return (0,);
        }

        let (l_vote) = votingbooth_lastvote.read(pillId);
        let (cur_ts) = get_block_timestamp();
        tempvar ts_diff = cur_ts - l_vote;
        return (ts_diff,);
    }

    func getPillContract{syscall_ptr: felt*, range_check_ptr, pedersen_ptr: HashBuiltin*}() -> (
        address: felt
    ) {
        let (address) = votingbooth_starkpill_contract.read();
        return (address,);
    }

    // -------------------------------------------------------------------------- //
    //                                  externals                                 //
    // -------------------------------------------------------------------------- //

    func execute_votes{
        bitwise_ptr: BitwiseBuiltin*,
        syscall_ptr: felt*,
        range_check_ptr,
        pedersen_ptr: HashBuiltin*,
    }(owner: felt, ammount: felt) {
        alloc_locals;
        let (local spill_addr) = votingbooth_starkpill_contract.read();
        let (local caller) = get_caller_address();
        // assert that caller is SPILL contract
        with_attr error_message("votingBooth: only starkpill contract allowed") {
            assert_not_zero(caller);
            assert caller = spill_addr;
        }

        // assert caller is valid address
        with_attr error_message("votingBooth: owner is an invalid address") {
            assert_not_zero(owner);
        }

        // assert ammount of vote is valid
        with_attr error_message("votingBooth: voting ammount is invalid") {
            let is_valid = is_le(1, ammount);
            assert is_valid = TRUE;
        }

        // assert balance is not zero
        let (balance: Uint256) = ISPILL.balanceOf(spill_addr, owner);
        with_attr error_message("votingBooth: not enough votes") {
            let (is_zero) = uint256_le(balance, Uint256(0, 0));
            assert is_zero = FALSE;
        }

        _execute_vote_recursion(
            owner=owner, spill_addr=spill_addr, index=Uint256(0, 0), balance=balance, votes=ammount
        );
        return ();
    }

    func setPillContract{syscall_ptr: felt*, range_check_ptr, pedersen_ptr: HashBuiltin*}(
        address: felt
    ) {
        with_attr error_message("votingBooth: invalid address") {
            assert_not_zero(address);
        }
        votingbooth_starkpill_contract.write(address);
        return ();
    }
}
// -------------------------------------------------------------------------- //
//                                  internals                                 //
// -------------------------------------------------------------------------- //

func _getOwnerVote_recursion{
    bitwise_ptr: BitwiseBuiltin*, syscall_ptr: felt*, range_check_ptr, pedersen_ptr: HashBuiltin*
}(owner: felt, spill_addr: felt, index: Uint256, balance: Uint256, count: felt) -> (votes: felt) {
    alloc_locals;
    let (is_equal) = uint256_le(balance, index);
    if (is_equal == TRUE) {
        return (count,);
    }

    let (tokenId: Uint256) = ISPILL.tokenOfOwnerByIndex(spill_addr, owner, index);
    let (slot: Uint256) = ISPILL.slotOf(spill_addr, tokenId);
    let (is_pill) = uint256_eq(slot, Uint256(1, 0));

    // if not pill skip to next
    if (is_pill == FALSE) {
        let (new_index: Uint256) = SafeUint256.add(index, Uint256(1, 0));
        return _getOwnerVote_recursion(owner, spill_addr, new_index, balance, count);
    }

    // check if pill can vote
    // if cant vote skip to next
    let (can_vote) = _check_can_token_vote(spill_addr, tokenId);
    if (can_vote == FALSE) {
        let (new_index: Uint256) = SafeUint256.add(index, Uint256(1, 0));
        return _getOwnerVote_recursion(owner, spill_addr, new_index, balance, count);
    }

    let (new_index: Uint256) = SafeUint256.add(index, Uint256(1, 0));
    let (pill_votes) = _get_pill_voting_power(spill_addr, tokenId);
    tempvar new_count = pill_votes + count;

    return _getOwnerVote_recursion(owner, spill_addr, new_index, balance, new_count);
}

// if ammount of votes is more than one at the end of recursion
// tx will fail as it means ammount of votes exceed owner voting power
func _execute_vote_recursion{
    bitwise_ptr: BitwiseBuiltin*, syscall_ptr: felt*, range_check_ptr, pedersen_ptr: HashBuiltin*
}(owner: felt, spill_addr: felt, index: Uint256, balance: Uint256, votes: felt) {
    alloc_locals;
    // check if finish voting
    let no_votes = is_le(votes, 0);
    if (no_votes == TRUE) {
        return ();
    }

    // check if its at the end of recursion
    // will fail as no_votes will equal to false
    let (is_equal) = uint256_le(balance, index);
    if (is_equal == TRUE) {
        with_attr error_message("votingBooth: not enough votes") {
            assert no_votes = TRUE;
        }
        return ();
    }

    let (tokenId: Uint256) = ISPILL.tokenOfOwnerByIndex(spill_addr, owner, index);
    let (slot: Uint256) = ISPILL.slotOf(spill_addr, tokenId);
    let (is_pill) = uint256_eq(slot, Uint256(1, 0));

    // if not pill skip to next
    if (is_pill == FALSE) {
        let (new_index: Uint256) = SafeUint256.add(index, Uint256(1, 0));
        return _execute_vote_recursion(owner, spill_addr, new_index, balance, votes);
    }

    // check if pill can vote
    // if cant vote skip to next
    let (can_vote) = _check_can_token_vote(spill_addr, tokenId);
    if (can_vote == FALSE) {
        let (new_index: Uint256) = SafeUint256.add(index, Uint256(1, 0));
        return _execute_vote_recursion(owner, spill_addr, new_index, balance, votes);
    }

    // execute votes on pill
    let (new_index: Uint256) = SafeUint256.add(index, Uint256(1, 0));
    let (remainder_votes) = _execute_pill_votes(spill_addr, tokenId, votes);

    return _execute_vote_recursion(owner, spill_addr, new_index, balance, remainder_votes);
}

// check a pill ID to see if their traits are premium
// checks for attriD 1 -> medical bill
// checks if the trait has already voted
// voting hierachy 1 -> ingId, 2 -> bgId, 3 -> tokenId
// returns ammount of votes left after execution
func _execute_pill_votes{
    bitwise_ptr: BitwiseBuiltin*, syscall_ptr: felt*, range_check_ptr, pedersen_ptr: HashBuiltin*
}(spill_addr: felt, pillId: Uint256, votes: felt) -> (votes_left: felt) {
    alloc_locals;
    let (ingId: Uint256, bgId: Uint256, _) = ISPILL.getPrescription(spill_addr, pillId);
    let (cur_ts) = get_block_timestamp();

    // try vote with ingredient
    let (remaining_vote_1) = _try_vote_trait(spill_addr, pillId, ingId, cur_ts, votes);
    // try vote with background
    let (remaining_vote_2) = _try_vote_trait(spill_addr, pillId, bgId, cur_ts, remaining_vote_1);
    // try vote with pill
    // assumes pill can vote
    let (remaining_vote_final) = _try_vote_pill(pillId, cur_ts, remaining_vote_2);

    return (remaining_vote_final,);
}

// if votes == 0 means stop using pill votes
func _try_vote_trait{
    bitwise_ptr: BitwiseBuiltin*, syscall_ptr: felt*, range_check_ptr, pedersen_ptr: HashBuiltin*
}(spill_addr: felt, pillId: Uint256, traitId: Uint256, time_stamp: felt, votes: felt) -> (
    votes_remaining: felt
) {
    // if no_votes left ignore
    if (votes == 0) {
        return (0,);
    }

    let (can_vote) = _check_can_token_vote(spill_addr, traitId);
    if (can_vote == TRUE) {
        votingbooth_lastvote.write(traitId, time_stamp);
        TraitVoteTimeStamp.emit(pillId, traitId, time_stamp);
        return (votes - 1,);
    } else {
        return (votes,);
    }
}

// if votes == 0 means stop using pill votes
// assumes pill can vote
func _try_vote_pill{syscall_ptr: felt*, range_check_ptr, pedersen_ptr: HashBuiltin*}(
    pillId: Uint256, time_stamp: felt, votes: felt
) -> (votes_remaining: felt) {
    if (votes == 0) {
        return (0,);
    }

    votingbooth_lastvote.write(pillId, time_stamp);
    PillVoteTimeStamp.emit(pillId, time_stamp);
    return (votes - 1,);
}

func _get_pill_voting_power{
    bitwise_ptr: BitwiseBuiltin*, syscall_ptr: felt*, range_check_ptr, pedersen_ptr: HashBuiltin*
}(spill_addr: felt, pillId: Uint256) -> (ammount: felt) {
    alloc_locals;

    let (can_pill_vote) = _check_can_token_vote(spill_addr, pillId);
    if (can_pill_vote == FALSE) {
        return (0,);
    }

    let (ingId: Uint256, bgId: Uint256, _) = ISPILL.getPrescription(spill_addr, pillId);
    let (can_ing_vote) = _check_can_token_vote(spill_addr, ingId);
    let (can_bg_vote) = _check_can_token_vote(spill_addr, bgId);

    tempvar total_votes = can_ing_vote + can_bg_vote + can_pill_vote;
    return (total_votes,);
}

// check if tokenId can vote
// checks for attrId 1
// checks for block_time_stamp
func _check_can_token_vote{
    bitwise_ptr: BitwiseBuiltin*, syscall_ptr: felt*, range_check_ptr, pedersen_ptr: HashBuiltin*
}(spill_addr: felt, tokenId: Uint256) -> (can_vote: felt) {
    alloc_locals;
    let (is_zero) = uint256_le(tokenId, Uint256(0, 0));
    if (is_zero == TRUE) {
        return (FALSE,);
    } else {
        // check for attrID 1 ammount
        let (ammount: Uint256) = ISPILL.attributeAmmount(spill_addr, tokenId, Uint256(1, 0));
        let (has_attr) = uint256_le(Uint256(1, 0), ammount);
        if (has_attr == TRUE) {
            // check if it can vote
            let (l_vote) = votingbooth_lastvote.read(tokenId);
            let (cur_ts) = get_block_timestamp();
            tempvar ts_diff = cur_ts - l_vote;
            let has_been_a_day = is_le(86400, ts_diff);
            return (has_been_a_day,);
        } else {
            return (FALSE,);
        }
    }
}
