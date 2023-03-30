%lang starknet
%builtins pedersen range_check bitwise

from starkware.cairo.common.cairo_builtins import HashBuiltin, SignatureBuiltin, BitwiseBuiltin
from starkware.cairo.common.uint256 import Uint256
// --------------------------------- my libs -------------------------------- //
from testpill.libs.roles.AccessControl import AccessControl
from testpill.libs.proxy.library import Proxy
from testpill.contracts.votingboothV1.library import VotingBooth

@external
func initializer{syscall_ptr: felt*, range_check_ptr, pedersen_ptr: HashBuiltin*}(
    admin: felt, starkpill_addr: felt
) {
    // proxy initializer already checks if contract has been initialized before
    // and will revert if it is
    Proxy.initializer(admin);
    VotingBooth.initializer(starkpill_addr);
    return ();
}

// -------------------------------------------------------------------------- //
//                           voting booth view func                           //
// -------------------------------------------------------------------------- //

@view
func getOwnerVotes{
    bitwise_ptr: BitwiseBuiltin*, syscall_ptr: felt*, range_check_ptr, pedersen_ptr: HashBuiltin*
}(owner: felt) -> (ammount: felt) {
    return VotingBooth.getOwnerVotes(owner);
}

@view
func getPillVotingPower{
    bitwise_ptr: BitwiseBuiltin*, syscall_ptr: felt*, range_check_ptr, pedersen_ptr: HashBuiltin*
}(pillId: Uint256) -> (ammount: felt) {
    return VotingBooth.getPillVotingPower(pillId);
}

@view
func getPillVoteTimer{
    bitwise_ptr: BitwiseBuiltin*, syscall_ptr: felt*, range_check_ptr, pedersen_ptr: HashBuiltin*
}(pillId: Uint256) -> (time: felt) {
    return VotingBooth.getPillVoteTimer(pillId);
}

@view
func getPillContract{syscall_ptr: felt*, range_check_ptr, pedersen_ptr: HashBuiltin*}() -> (
    address: felt
) {
    return VotingBooth.getPillContract();
}

// -------------------------------------------------------------------------- //
//                               proxy view func                              //
// -------------------------------------------------------------------------- //
@view
func implementation{syscall_ptr: felt*, range_check_ptr, pedersen_ptr: HashBuiltin*}() -> (
    implementation: felt
) {
    let (implementation) = Proxy.get_implementation_hash();
    return (implementation,);
}

// -------------------------------------------------------------------------- //
//                           voting booth externals                           //
// -------------------------------------------------------------------------- //

@external
func execute_votes{
    bitwise_ptr: BitwiseBuiltin*, syscall_ptr: felt*, range_check_ptr, pedersen_ptr: HashBuiltin*
}(owner: felt, ammount: felt) {
    VotingBooth.execute_votes(owner, ammount);
    return ();
}

@external
func setPillContract{syscall_ptr: felt*, range_check_ptr, pedersen_ptr: HashBuiltin*}(
    address: felt
) {
    AccessControl.only_admin();
    VotingBooth.setPillContract(address);
    return ();
}

// -------------------------------------------------------------------------- //
//                           accesscontrol externals                          //
// -------------------------------------------------------------------------- //
@external
func grantAdminRole{syscall_ptr: felt*, range_check_ptr, pedersen_ptr: HashBuiltin*}(admin: felt) {
    alloc_locals;
    AccessControl.grant_admin_role(admin);
    return ();
}

@external
func revokeAdminRole{syscall_ptr: felt*, range_check_ptr, pedersen_ptr: HashBuiltin*}(admin: felt) {
    alloc_locals;
    AccessControl.revoke_admin_role(admin);
    return ();
}

// -------------------------------------------------------------------------- //
//                               proxy externals                              //
// -------------------------------------------------------------------------- //
@external
func upgrade{syscall_ptr: felt*, range_check_ptr, pedersen_ptr: HashBuiltin*}(
    implementation: felt
) {
    alloc_locals;
    AccessControl.only_admin();
    Proxy._set_implementation_hash(implementation);
    return ();
}
