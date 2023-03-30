%lang starknet

from starkware.starknet.common.syscalls import get_caller_address
from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.bool import TRUE, FALSE
from starkware.cairo.common.math import assert_not_zero
from testpill.libs.roles.AccessControl import AccessControl
//
// Events
//

@event
func Upgraded(implementation: felt) {
}

@event
func AdminChanged(previousAdmin: felt, newAdmin: felt) {
}

//
// Storage variables
//

@storage_var
func Proxy_implementation_hash() -> (implementation: felt) {
}

@storage_var
func Proxy_initialized() -> (initialized: felt) {
}

namespace Proxy {
    //
    // Initializer
    //

    func initializer{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(admin: felt) {
        let (initialized) = Proxy_initialized.read();
        with_attr error_message("Proxy: contract already initialized") {
            assert initialized = FALSE;
        }
        Proxy_initialized.write(TRUE);
        AccessControl.initializer(admin);
        return ();
    }

    //
    // Getters
    //

    func get_implementation_hash{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        ) -> (implementation: felt) {
        return Proxy_implementation_hash.read();
    }

    //
    // Upgrade
    //

    func _set_implementation_hash{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        new_implementation: felt
    ) {
        with_attr error_message("Proxy: implementation hash cannot be zero") {
            assert_not_zero(new_implementation);
        }

        Proxy_implementation_hash.write(new_implementation);
        Upgraded.emit(new_implementation);
        return ();
    }
}
