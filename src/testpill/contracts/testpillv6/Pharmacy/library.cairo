%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin, SignatureBuiltin, BitwiseBuiltin
from starkware.cairo.common.math import assert_not_zero, assert_le
from starkware.cairo.common.math_cmp import is_nn_le
from starkware.cairo.common.bool import TRUE, FALSE
from starkware.cairo.common.uint256 import Uint256, uint256_check, uint256_le, uint256_lt
from starkware.cairo.common.registers import get_label_location
from SeraphLabs.models.StringObject import StrObj

// -------------------------------------------------------------------------- //
//                                  constants                                 //
// -------------------------------------------------------------------------- //
const MAX_INGREDIENT = 28;
const MAX_BACKGROUND = 18;

// -------------------------------------------------------------------------- //
//                                   events                                   //
// -------------------------------------------------------------------------- //
@event
func PharmacyStockUpdate(typeIndex: felt, index: felt, startAmmount: felt, ammount_left: felt) {
}

// -------------------------------------------------------------------------- //
//                                   storage                                  //
// -------------------------------------------------------------------------- //
@storage_var
func starkpill_ing_price(index: felt) -> (price: Uint256) {
}

@storage_var
func starkpill_bg_price(index: felt) -> (price: Uint256) {
}

@storage_var
func starkpill_start_stock(typeIndex: felt, index: felt) -> (ammount: felt) {
}

@storage_var
func starkpill_end_stock(typeIndex: felt, index: felt) -> (ammount: felt) {
}

// -------------------------------------------------------------------------- //
//                                   structs                                  //
// -------------------------------------------------------------------------- //
struct PillBottle {
    ing: Uint256,
    BG: Uint256,
}

struct SPillAttr {
    attr: felt,
    file: felt,
}
namespace Pharmacy {
    func assertValidIngredientType{syscall_ptr: felt*, range_check_ptr, pedersen_ptr: HashBuiltin*}(
        index: felt
    ) {
        _assertValidIngredientType(index);
        return ();
    }

    func assertValidBackgroundType{syscall_ptr: felt*, range_check_ptr, pedersen_ptr: HashBuiltin*}(
        index: felt
    ) {
        _assertValidBackgroundType(index);
        return ();
    }

    func getPillIngredient{syscall_ptr: felt*, range_check_ptr, pedersen_ptr: HashBuiltin*}(
        index: felt
    ) -> (res: SPillAttr) {
        alloc_locals;
        _assertValidIngredientType(index);
        let (res: SPillAttr) = _getPillingredient(index);
        return (res,);
    }

    func getPillBackground{syscall_ptr: felt*, range_check_ptr, pedersen_ptr: HashBuiltin*}(
        index: felt
    ) -> (res: SPillAttr) {
        alloc_locals;
        _assertValidBackgroundType(index);
        let (res: SPillAttr) = _getPillBackGround(index);
        return (res,);
    }

    func getIngredientPrice{syscall_ptr: felt*, range_check_ptr, pedersen_ptr: HashBuiltin*}(
        index: felt
    ) -> (price: Uint256) {
        let (price: Uint256) = starkpill_ing_price.read(index);
        return (price,);
    }

    func getBackgroundPrice{syscall_ptr: felt*, range_check_ptr, pedersen_ptr: HashBuiltin*}(
        index: felt
    ) -> (price: Uint256) {
        let (price: Uint256) = starkpill_bg_price.read(index);
        return (price,);
    }

    func getStock{syscall_ptr: felt*, range_check_ptr, pedersen_ptr: HashBuiltin*}(
        typeIndex: felt, index: felt
    ) -> (start_ammount: felt, ammount_left: felt) {
        alloc_locals;
        // get starting ammount
        let (start_ammount) = starkpill_start_stock.read(typeIndex, index);
        // get ammount used
        let (end_ammount) = starkpill_end_stock.read(typeIndex, index);
        // get ammount left
        tempvar ammount_left = start_ammount - end_ammount;
        return (start_ammount, ammount_left);
    }

    func setIngPrice{syscall_ptr: felt*, range_check_ptr, pedersen_ptr: HashBuiltin*}(
        index: felt, price: Uint256
    ) {
        starkpill_ing_price.write(index, price);
        return ();
    }

    func setBgPrice{syscall_ptr: felt*, range_check_ptr, pedersen_ptr: HashBuiltin*}(
        index: felt, price: Uint256
    ) {
        starkpill_bg_price.write(index, price);
        return ();
    }

    func addStock{syscall_ptr: felt*, range_check_ptr, pedersen_ptr: HashBuiltin*}(
        typeIndex: felt, index: felt, ammount: felt
    ) {
        alloc_locals;
        _assertValidStock(typeIndex, index, ammount);
        if (ammount == 0) {
            _resetStock(typeIndex, index);
            PharmacyStockUpdate.emit(typeIndex, index, 0, 0);
            return ();
        } else {
            // add new starting ammount to stock
            let (cur_ammt) = starkpill_start_stock.read(typeIndex, index);
            tempvar new_ammt = cur_ammt + ammount;
            starkpill_start_stock.write(typeIndex, index, new_ammt);
            // emit event
            let (_, ammount_left) = getStock(typeIndex, index);
            PharmacyStockUpdate.emit(typeIndex, index, new_ammt, ammount_left);
            return ();
        }
    }

    // clear stock on mint
    // assumes valid index
    func clearStock{syscall_ptr: felt*, range_check_ptr, pedersen_ptr: HashBuiltin*}(
        typeIndex: felt, index: felt
    ) {
        alloc_locals;
        let (start_stock) = starkpill_start_stock.read(typeIndex, index);
        // if start_ammount is 0 means infinite mint
        if (start_stock == 0) {
            return ();
        } else {
            let (end_stock) = starkpill_end_stock.read(typeIndex, index);
            // ensure that ammount left is >= 1
            tempvar ammount_left = start_stock - end_stock;
            with_attr error_message("Pharmacy: not enough stock") {
                let can_clear = is_nn_le(1, ammount_left);
                assert can_clear = TRUE;
            }
            starkpill_end_stock.write(typeIndex, index, end_stock + 1);
            // emit event
            PharmacyStockUpdate.emit(typeIndex, index, start_stock, ammount_left - 1);
            return ();
        }
    }
}

// -------------------------------------------------------------------------- //
//                                   private                                  //
// -------------------------------------------------------------------------- //
func _assertValidIngredientType{syscall_ptr: felt*, range_check_ptr, pedersen_ptr: HashBuiltin*}(
    index: felt
) {
    with_attr error_message("Pharmacy: no such ingredient type") {
        let is_valid = is_nn_le(index, MAX_INGREDIENT);
        assert is_valid = TRUE;
    }
    return ();
}

func _assertValidBackgroundType{syscall_ptr: felt*, range_check_ptr, pedersen_ptr: HashBuiltin*}(
    index: felt
) {
    with_attr error_message("Pharmacy: no such background type") {
        let is_valid = is_nn_le(index, MAX_BACKGROUND);
        assert is_valid = TRUE;
    }
    return ();
}

// asserts that typeIndex is either 1 or 2
// asserts that index is a valid type
// assert that ammount >= 0
func _assertValidStock{syscall_ptr: felt*, range_check_ptr, pedersen_ptr: HashBuiltin*}(
    typeIndex: felt, index: felt, ammount: felt
) {
    alloc_locals;
    with_attr error_message("Pharmacy: invalid ammount") {
        let is_valid = is_nn_le(0, ammount);
        assert is_valid = TRUE;
    }

    // check valid ingredient type
    if (typeIndex == 1) {
        _assertValidIngredientType(index);
        return ();
    }

    // check valid background type
    if (typeIndex == 2) {
        _assertValidBackgroundType(index);
        return ();
    }
    // if typeIndex is neither 1 or 2 fail the tx
    with_attr error_message("Pharmacy: typeIndex is out of bounds") {
        assert 1 = 0;
    }
    return ();
}

// used to set unlimted stock for mint
// assumes valid index
func _resetStock{syscall_ptr: felt*, range_check_ptr, pedersen_ptr: HashBuiltin*}(
    typeIndex: felt, index: felt
) {
    alloc_locals;
    // clear starting limit
    starkpill_start_stock.write(typeIndex, index, 0);
    // clear ammount used
    starkpill_end_stock.write(typeIndex, index, 0);
    return ();
}

// -------------------------------------------------------------------------- //
//                                  internals                                 //
// -------------------------------------------------------------------------- //
func _getPillingredient(i) -> (Attr: SPillAttr) {
    let (word_addr) = get_label_location(word);
    let (file_addr) = get_label_location(file);
    return (SPillAttr([word_addr + i], [file_addr + i]),);

    word:
    dw '"Null"';
    dw '"Briq"';
    dw '"Braavos"';
    dw '"Orbiter"';
    dw '"ChainLink Cap"';
    dw '"Guthmann"';
    dw '"Kitsune Mask"';
    dw '"Wassie Face"';
    dw '"Wassie Cone"';
    dw '"Kabuto Helmet"';
    dw '"Cairo Cap"';
    dw '"Bunny Plush"';
    dw '"Cartridge"';
    dw '"Mfers"';
    dw '"Braavos Titan"';
    dw '"Braavos Archer"';
    dw '"Braavos Wizard"';
    dw '"zkSnails"';
    dw '"(3,3) Face"';
    dw '"Aviators"';
    dw '"Banteg Hat"';
    dw '"Pepe"';
    dw '"Pepe Smile"';
    dw '"Pepe Smug"';
    dw '"Peepo Smile"';
    dw '"Wojak"';
    dw '"Wojak Big Brain"';
    dw '"Wojak Cope"';
    dw '"Wojak Doomer"';

    file:
    dw '000';
    dw '001';
    dw '002';
    dw '003';
    dw '004';
    dw '005';
    dw '006';
    dw '007';
    dw '008';
    dw '009';
    dw '010';
    dw '011';
    dw '012';
    dw '013';
    dw '014';
    dw '015';
    dw '016';
    dw '017';
    dw '018';
    dw '019';
    dw '020';
    dw '021';
    dw '022';
    dw '023';
    dw '024';
    dw '025';
    dw '026';
    dw '027';
    dw '028';
}

func _getPillBackGround(i) -> (Attr: SPillAttr) {
    let (word_addr) = get_label_location(word);
    let (file_addr) = get_label_location(file);
    return (SPillAttr([word_addr + i], [file_addr + i]),);

    word:
    dw '"White"';
    dw '"Yellow"';
    dw '"Pink"';
    dw '"Purple"';
    dw '"Cyan"';
    dw '"Green"';
    dw '"Aquarius Sky Vaporwave"';
    dw '"Galaxy Oil Painting"';
    dw '"Rocket"';
    dw '"Cloudy Kingdom"';
    dw '"Training Grounds"';
    dw '"Medicine Cabinet"';
    dw '"Night Sky"';
    dw '"Violet Swirl"';
    dw '"Train Tracks"';
    dw '"Cartridge"';
    dw '"Eastern Palace"';
    dw '"Fortress City"';
    dw '"Impenetrable Defense"';

    file:
    dw '000';
    dw '001';
    dw '002';
    dw '003';
    dw '004';
    dw '005';
    dw '006';
    dw '007';
    dw '008';
    dw '009';
    dw '010';
    dw '011';
    dw '012';
    dw '013';
    dw '014';
    dw '015';
    dw '016';
    dw '017';
    dw '018';
}
