%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from openzeppelin.introspection.ERC165.library import ERC165

func erc165supportsInterface{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    interfaceId: felt
) -> (success: felt) {
    return ERC165.supports_interface(interfaceId);
}
