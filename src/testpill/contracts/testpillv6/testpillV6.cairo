%lang starknet
%builtins pedersen range_check bitwise

from starkware.cairo.common.cairo_builtins import HashBuiltin, SignatureBuiltin, BitwiseBuiltin
from starkware.cairo.common.uint256 import Uint256
// --------------------------------- my libs -------------------------------- //
from testpill.libs.roles.AccessControl import AccessControl
from testpill.libs.Pausable import Pausable
from testpill.libs.proxy.library import Proxy
// ------------------------------- token libs ------------------------------- //
from testpill.utils.erc165utils import erc165supportsInterface
from SeraphLabs.tokens.ERC721S.library import (
    ERC721S_initializer,
    ERC721S_name,
    ERC721S_symbol,
    ERC721S_total_supply,
    ERC721S_balanceOf,
    ERC721S_ownerOf,
    ERC721S_isApprovedForAll,
    ERC721S_tokenOfOwnerByIndex,
    ERC721S_tokenByIndex,
    ERC721S_getApproved,
    ERC721S_approve,
    ERC721S_transferFrom,
    ERC721S_setApprovalForAll,
)

from SeraphLabs.tokens.ERC3525.library import (
    ERC3525_initializer,
    ERC3525_slotOf,
    ERC3525_supplyOfSlot,
    ERC3525_tokenOfSlotByIndex,
    ERC3525_clearUnitApprovals,
)

from SeraphLabs.tokens.ERC2114.library import (
    ERC2114_tokenOf,
    ERC2114_tokenBalanceOf,
    ERC2114_initializer,
    ERC2114_attributeAmmount,
    _ERC2114_assert_notOwnedByToken,
)

from SeraphLabs.tokens.ERC2114.enumerable.library import (
    ERC2114Enumerable_initializer,
    ERC2114Enumerable_tokenOfTokenByIndex,
)
// -------------------------------- constants ------------------------------- //
from testpill.utils.PillConstants.library import NAME, SYMBOL
// ----------------------------- starkpill libs ----------------------------- //
from testpill.contracts.testpillV6.library import StarkPill
from testpill.contracts.testpillV6.PillFame.library import PillFame
from testpill.contracts.testpillV6.tokenURI.library import StarkPillURI

// -------------------------------------------------------------------------- //
//                                 initalizer                                 //
// -------------------------------------------------------------------------- //
@external
func initializer{syscall_ptr: felt*, range_check_ptr, pedersen_ptr: HashBuiltin*}(admin: felt) {
    // proxy initializer already checks if contract has been initialized before
    // and will revert if it is
    Proxy.initializer(admin);
    ERC721S_initializer(NAME, SYMBOL);
    ERC3525_initializer();
    ERC2114_initializer();
    ERC2114Enumerable_initializer();
    StarkPill.initializer(
        0x049d36570d4e46f48e99674bd3fcc84644ddd6b96f7c741b1562b82f9e004dc7,
        0x03dc7651E449431bEF33e4F7691c4a0574f90E072E346400d8fc9C44c0108A5C,
    );  // ! change to proper wallet address
    StarkPillURI.initializer();
    PillFame.initializer();
    return ();
}

// -------------------------------------------------------------------------- //
//                               721S view func                               //
// -------------------------------------------------------------------------- //

@view
func supportsInterface{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    interfaceId: felt
) -> (success: felt) {
    return erc165supportsInterface(interfaceId);
}

@view
func name{syscall_ptr: felt*, range_check_ptr, pedersen_ptr: HashBuiltin*}() -> (name: felt) {
    let (name) = ERC721S_name();
    return (name,);
}

@view
func symbol{syscall_ptr: felt*, range_check_ptr, pedersen_ptr: HashBuiltin*}() -> (symbol: felt) {
    let (symbol) = ERC721S_symbol();
    return (symbol,);
}

@view
func totalSupply{syscall_ptr: felt*, range_check_ptr, pedersen_ptr: HashBuiltin*}() -> (
    supply: Uint256
) {
    let (res: Uint256) = ERC721S_total_supply();
    return (res,);
}

@view
func balanceOf{syscall_ptr: felt*, range_check_ptr, pedersen_ptr: HashBuiltin*}(owner: felt) -> (
    balance: Uint256
) {
    let (balance: Uint256) = ERC721S_balanceOf(owner);
    return (balance,);
}

@view
func ownerOf{
    bitwise_ptr: BitwiseBuiltin*, syscall_ptr: felt*, range_check_ptr, pedersen_ptr: HashBuiltin*
}(tokenId: Uint256) -> (owner: felt) {
    let (owner) = ERC721S_ownerOf(tokenId);
    return (owner,);
}

@view
func tokenOfOwnerByIndex{
    bitwise_ptr: BitwiseBuiltin*, syscall_ptr: felt*, range_check_ptr, pedersen_ptr: HashBuiltin*
}(owner: felt, index: Uint256) -> (tokenId: Uint256) {
    let (tokenId: Uint256) = ERC721S_tokenOfOwnerByIndex(owner, index);
    return (tokenId,);
}

@view
func tokenByIndex{
    bitwise_ptr: BitwiseBuiltin*, syscall_ptr: felt*, range_check_ptr, pedersen_ptr: HashBuiltin*
}(index: Uint256) -> (tokenId: Uint256) {
    let (tokenId: Uint256) = ERC721S_tokenByIndex(index);
    return (tokenId,);
}

@view
func getApproved{
    bitwise_ptr: BitwiseBuiltin*, syscall_ptr: felt*, range_check_ptr, pedersen_ptr: HashBuiltin*
}(tokenId: Uint256) -> (approved: felt) {
    let (approved) = ERC721S_getApproved(tokenId);
    return (approved,);
}

@view
func isApprovedForAll{syscall_ptr: felt*, range_check_ptr, pedersen_ptr: HashBuiltin*}(
    owner: felt, operator: felt
) -> (is_approved: felt) {
    let (is_approved) = ERC721S_isApprovedForAll(owner, operator);
    return (is_approved,);
}

@view
func tokenURI{
    bitwise_ptr: BitwiseBuiltin*, syscall_ptr: felt*, range_check_ptr, pedersen_ptr: HashBuiltin*
}(tokenId: Uint256) -> (tokenURI_len: felt, tokenURI: felt*) {
    let (tokenURI_len, tokenURI) = StarkPillURI.tokenURI(tokenId);
    return (tokenURI_len, tokenURI);
}
// ---------------------------------------------------------------------------- #
//                            ERC3525 view functions                            #
// ---------------------------------------------------------------------------- #

@view
func slotOf{
    bitwise_ptr: BitwiseBuiltin*, syscall_ptr: felt*, range_check_ptr, pedersen_ptr: HashBuiltin*
}(tokenId: Uint256) -> (slot: Uint256) {
    let (slot: Uint256) = ERC3525_slotOf(tokenId);
    return (slot,);
}

@view
func supplyOfSlot{syscall_ptr: felt*, range_check_ptr, pedersen_ptr: HashBuiltin*}(
    slot: Uint256
) -> (supply: Uint256) {
    let (supply: Uint256) = ERC3525_supplyOfSlot(slot);
    return (supply,);
}

// @view
// func tokenOfSlotByIndex{
//     bitwise_ptr: BitwiseBuiltin*, syscall_ptr: felt*, range_check_ptr, pedersen_ptr: HashBuiltin*
// }(slot: Uint256, index: Uint256) -> (tokenId: Uint256) {
//     let (tokenId: Uint256) = ERC3525_tokenOfSlotByIndex(slot, index);
//     return (tokenId,);
// }

// -------------------------------------------------------------------------- //
//                               2114 view func                               //
// -------------------------------------------------------------------------- //
@view
func tokenOf{
    bitwise_ptr: BitwiseBuiltin*, syscall_ptr: felt*, range_check_ptr, pedersen_ptr: HashBuiltin*
}(tokenId: Uint256) -> (fromTokenId: Uint256, fromContract: felt) {
    return ERC2114_tokenOf(tokenId);
}

@view
func tokenBalanceOf{
    bitwise_ptr: BitwiseBuiltin*, syscall_ptr: felt*, range_check_ptr, pedersen_ptr: HashBuiltin*
}(tokenId: Uint256) -> (balance: Uint256) {
    return ERC2114_tokenBalanceOf(tokenId);
}

@view
func tokenOfTokenByIndex{
    bitwise_ptr: BitwiseBuiltin*, syscall_ptr: felt*, range_check_ptr, pedersen_ptr: HashBuiltin*
}(tokenId: Uint256, index: Uint256) -> (tokenId: Uint256, from_: felt) {
    let (token_id, from_) = ERC2114Enumerable_tokenOfTokenByIndex(tokenId, index);
    return (token_id, from_);
}

@view
func attributeAmmount{
    bitwise_ptr: BitwiseBuiltin*, syscall_ptr: felt*, range_check_ptr, pedersen_ptr: HashBuiltin*
}(tokenId: Uint256, attrId: Uint256) -> (ammount: Uint256) {
    return ERC2114_attributeAmmount(tokenId, attrId);
}

// -------------------------------------------------------------------------- //
//                             starkPill view func                            //
// -------------------------------------------------------------------------- //

@view
func getPrescription{
    bitwise_ptr: BitwiseBuiltin*, syscall_ptr: felt*, range_check_ptr, pedersen_ptr: HashBuiltin*
}(tokenId: Uint256) -> (ingredient: Uint256, Background: Uint256, price: Uint256) {
    return StarkPill.getPrescription(tokenId);
}

@view
func getPillFameLevels{
    bitwise_ptr: BitwiseBuiltin*, syscall_ptr: felt*, range_check_ptr, pedersen_ptr: HashBuiltin*
}(tokenId: Uint256) -> (fame: felt, defame: felt) {
    return PillFame.getPillFameLevels(tokenId);
}

@view
func getIngredientPremium{syscall_ptr: felt*, range_check_ptr, pedersen_ptr: HashBuiltin*}(
    ingredientType: felt
) -> (premium: Uint256) {
    let (premium) = StarkPill.getIngredientPremium(ingredientType);
    return (premium,);
}

@view
func getBackgroundPremium{syscall_ptr: felt*, range_check_ptr, pedersen_ptr: HashBuiltin*}(
    backgroundType: felt
) -> (premium: Uint256) {
    let (premium) = StarkPill.getBackgroundPremium(backgroundType);
    return (premium,);
}

@view
func getStock{syscall_ptr: felt*, range_check_ptr, pedersen_ptr: HashBuiltin*}(
    typeIndex: felt, index: felt
) -> (start_ammount: felt, ammount_left: felt) {
    return StarkPill.getStock(typeIndex, index);
}

@view
func getVotingBoothContract{syscall_ptr: felt*, range_check_ptr, pedersen_ptr: HashBuiltin*}() -> (
    address: felt
) {
    return PillFame.getVotingBoothContract();
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
//                             721S external funcs                            //
// -------------------------------------------------------------------------- //
@external
func setApprovalForAll{syscall_ptr: felt*, range_check_ptr, pedersen_ptr: HashBuiltin*}(
    operator: felt, approved: felt
) {
    ERC721S_setApprovalForAll(operator, approved);
    return ();
}

@external
func approve{
    bitwise_ptr: BitwiseBuiltin*, syscall_ptr: felt*, range_check_ptr, pedersen_ptr: HashBuiltin*
}(to: felt, tokenId: Uint256) {
    ERC721S_approve(to, tokenId);
    return ();
}

@external
func transferFrom{
    bitwise_ptr: BitwiseBuiltin*, syscall_ptr: felt*, range_check_ptr, pedersen_ptr: HashBuiltin*
}(from_: felt, to: felt, tokenId: Uint256) {
    Pausable.assert_not_paused();
    _ERC2114_assert_notOwnedByToken(tokenId);
    ERC721S_transferFrom(from_, to, tokenId);
    ERC3525_clearUnitApprovals(tokenId);
    return ();
}

@external
func setTokenURI{syscall_ptr: felt*, range_check_ptr, pedersen_ptr: HashBuiltin*}(
    tokenURI_len: felt, tokenURI: felt*
) {
    AccessControl.only_admin();
    Pausable.assert_paused();
    StarkPillURI.setBaseTokenURI(tokenURI_len, tokenURI);
    return ();
}
// -------------------------------------------------------------------------- //
//                               2114 externals                               //
// -------------------------------------------------------------------------- //
@external
func scalarTransferFrom{
    bitwise_ptr: BitwiseBuiltin*, syscall_ptr: felt*, range_check_ptr, pedersen_ptr: HashBuiltin*
}(from_: felt, tokenId: Uint256, to: Uint256) {
    Pausable.assert_not_paused();
    StarkPill.scalarTransferFrom(from_, tokenId, to);
    ERC3525_clearUnitApprovals(tokenId);
    return ();
}

@external
func scalarRemoveFrom{
    bitwise_ptr: BitwiseBuiltin*, syscall_ptr: felt*, range_check_ptr, pedersen_ptr: HashBuiltin*
}(from_: Uint256, tokenId: Uint256) {
    Pausable.assert_not_paused();
    StarkPill.scalarRemoveFrom(from_, tokenId);
    return ();
}

// -------------------------------------------------------------------------- //
//                             starkpill externals                            //
// -------------------------------------------------------------------------- //

@external
func mint{
    bitwise_ptr: BitwiseBuiltin*, syscall_ptr: felt*, range_check_ptr, pedersen_ptr: HashBuiltin*
}(ingredientType: felt, backgroundType: felt, price: Uint256) {
    Pausable.assert_not_paused();
    StarkPill.mintPill(ingredientType, backgroundType, price);
    return ();
}

@external
func famePill{
    bitwise_ptr: BitwiseBuiltin*, syscall_ptr: felt*, range_check_ptr, pedersen_ptr: HashBuiltin*
}(tokenId: Uint256, ammount: felt) {
    Pausable.assert_not_paused();
    PillFame.famePill(tokenId, ammount);
    return ();
}

@external
func deFamePill{
    bitwise_ptr: BitwiseBuiltin*, syscall_ptr: felt*, range_check_ptr, pedersen_ptr: HashBuiltin*
}(tokenId: Uint256, ammount: felt) {
    Pausable.assert_not_paused();
    PillFame.deFamePill(tokenId, ammount);
    return ();
}

@external
func setIngredientPremium{syscall_ptr: felt*, range_check_ptr, pedersen_ptr: HashBuiltin*}(
    index: felt, price: Uint256
) {
    AccessControl.only_admin();
    Pausable.assert_paused();
    StarkPill.setIngredientPremium(index, price);
    return ();
}

@external
func setBackgroundPremium{syscall_ptr: felt*, range_check_ptr, pedersen_ptr: HashBuiltin*}(
    index: felt, price: Uint256
) {
    AccessControl.only_admin();
    Pausable.assert_paused();
    StarkPill.setBackgroundPremium(index, price);
    return ();
}

@external
func updateStock{syscall_ptr: felt*, range_check_ptr, pedersen_ptr: HashBuiltin*}(
    typeIndex: felt, index: felt, ammount: felt
) {
    AccessControl.only_admin();
    Pausable.assert_paused();
    StarkPill.updateStock(typeIndex, index, ammount);
    return ();
}

@external
func setVotingBoothContract{syscall_ptr: felt*, range_check_ptr, pedersen_ptr: HashBuiltin*}(
    address: felt
) {
    AccessControl.only_admin();
    Pausable.assert_paused();
    PillFame.setVotingBoothContract(address);
    return ();
}
// -------------------------------------------------------------------------- //
//                           accesscontrol externals                          //
// -------------------------------------------------------------------------- //
@external
func pause{syscall_ptr: felt*, range_check_ptr, pedersen_ptr: HashBuiltin*}() {
    AccessControl.only_admin();
    Pausable._pause();
    return ();
}

@external
func unpause{syscall_ptr: felt*, range_check_ptr, pedersen_ptr: HashBuiltin*}() {
    AccessControl.only_admin();
    Pausable._unpause();
    return ();
}

@external
func grantAdminRole{syscall_ptr: felt*, range_check_ptr, pedersen_ptr: HashBuiltin*}(admin: felt) {
    alloc_locals;
    Pausable.assert_not_paused();
    AccessControl.grant_admin_role(admin);
    return ();
}

@external
func revokeAdminRole{syscall_ptr: felt*, range_check_ptr, pedersen_ptr: HashBuiltin*}(admin: felt) {
    alloc_locals;
    Pausable.assert_not_paused();
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
    Pausable.assert_paused();
    Proxy._set_implementation_hash(implementation);
    return ();
}
