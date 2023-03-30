%lang starknet

from starkware.cairo.common.uint256 import Uint256

@contract_interface
namespace ISPILL {
    func tokenOfOwnerByIndex(owner: felt, index: Uint256) -> (tokenId: Uint256) {
    }

    func balanceOf(owner: felt) -> (balance: Uint256) {
    }

    func slotOf(tokenId: Uint256) -> (slot: Uint256) {
    }

    func attributeAmmount(tokenId: Uint256, attrId: Uint256) -> (ammount: Uint256) {
    }

    func getPrescription(tokenId: Uint256) -> (
        ingredient: Uint256, Background: Uint256, price: Uint256
    ) {
    }
}
