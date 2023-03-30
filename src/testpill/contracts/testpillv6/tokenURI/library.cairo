%lang starknet

from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.cairo_builtins import HashBuiltin, SignatureBuiltin, BitwiseBuiltin
from starkware.cairo.common.uint256 import Uint256, uint256_le, uint256_eq
from starkware.cairo.common.math import assert_not_zero
from starkware.cairo.common.bool import TRUE, FALSE

// ------------------------------- token libs ------------------------------- //
from openzeppelin.introspection.ERC165.library import ERC165
from SeraphLabs.tokens.ERC3525.library import ERC3525_slotOf
// --------------------------------- my libs -------------------------------- //
from SeraphLabs.strings.AsciiEncode import interger_to_ascii
from SeraphLabs.strings.AsciiArray import uint256_to_ascii, word_to_ascii
from SeraphLabs.arrays.Array import Array
// ----------------------------- starkpill libs ----------------------------- //
from testpill.contracts.testpillV6.library import (
    _get_pill_data,
    _get_ingredient_data,
    _get_background_data,
)
from testpill.contracts.testpillV6.Pharmacy.library import SPillAttr
from testpill.contracts.testpillV6.PillFame.library import _get_pill_fame
// --------------------------- structs & constants -------------------------- //
from SeraphLabs.models.StringObject import StrObj
from SeraphLabs.utils.Constants import IERC721_METADATA_ID
from testpill.utils.PillConstants.library import (
    JSON_START,
    IMAGE_START,
    STARKPILL_FILE,
    INGREDIENT_FILE,
    BACKGROUND_FILE,
    IMAGE_END,
    ATTR1,
    ATTR2,
    ATTR3,
    ATTR4,
    ATTR5,
    SLOT1,
    SLOT2,
    SLOT3,
    DESC1_1,
    DESC1_2,
    DESC1_3,
    DESC2_1,
    DESC2_2,
    DESC2_3,
    ATTR_START,
    FIRST_TRAIT,
    NEXT_TRAIT,
    VALUE,
    JSON_END,
)
// ---------------------------------------------------------------------------- #
//                                    storage                                   #
// ---------------------------------------------------------------------------- #

@storage_var
func starkpill_Metadata_base_token_uri(index: felt) -> (res: felt) {
}

@storage_var
func starkpill_Metadata_base_token_uri_len() -> (res: felt) {
}

namespace StarkPillURI {
    // ---------------------------------------------------------------------------- #
    //                                  constructor                                 #
    // ---------------------------------------------------------------------------- #
    func initializer{syscall_ptr: felt*, range_check_ptr, pedersen_ptr: HashBuiltin*}() {
        ERC165.register_interface(IERC721_METADATA_ID);
        return ();
    }
    // -------------------------------------------------------------------------- //
    //                                    view                                    //
    // -------------------------------------------------------------------------- //
    func tokenURI{
        bitwise_ptr: BitwiseBuiltin*,
        syscall_ptr: felt*,
        range_check_ptr,
        pedersen_ptr: HashBuiltin*,
    }(tokenId: Uint256) -> (arr_len: felt, arr: felt*) {
        alloc_locals;
        let (local slot: Uint256) = ERC3525_slotOf(tokenId);
        // ------------------- ensures that tokenId 0 < slot <= 3 ------------------- //
        with_attr error_message("starkpill tokenId is invalid") {
            let (lesser_3) = uint256_le(slot, Uint256(3, 0));
            let (lesser_0) = uint256_le(slot, Uint256(0, 0));
            assert lesser_3 = TRUE;
            assert lesser_0 = FALSE;
        }

        let (is_ing) = uint256_eq(slot, Uint256(2, 0));
        if (is_ing == TRUE) {
            return _starkpill_Metadata_generateIngredientJson(tokenId);
        }

        let (is_bg) = uint256_eq(slot, Uint256(3, 0));
        if (is_bg == TRUE) {
            return _starkpill_Metadata_generateBackgroundJson(tokenId);
        }

        return _starkpill_Metadata_generatePillJson(tokenId);
    }
    // -------------------------------------------------------------------------- //
    //                                  externals                                 //
    // -------------------------------------------------------------------------- //
    func setBaseTokenURI{syscall_ptr: felt*, range_check_ptr, pedersen_ptr: HashBuiltin*}(
        tokenURI_len: felt, tokenURI: felt*
    ) {
        with_attr error_message("starkpill: invalid slot or array length") {
            assert_not_zero(tokenURI_len);
        }

        _starkpill_Metadata_setBaseTokenURI(tokenURI_len, tokenURI);
        starkpill_Metadata_base_token_uri_len.write(tokenURI_len);
        return ();
    }
}

// -------------------------------------------------------------------------- //
//                             metadata internals                             //
// -------------------------------------------------------------------------- //

func _starkpill_Metadata_generatePillJson{
    bitwise_ptr: BitwiseBuiltin*, syscall_ptr: felt*, range_check_ptr, pedersen_ptr: HashBuiltin*
}(tokenId: Uint256) -> (arr_len: felt, arr: felt*) {
    alloc_locals;
    let (local pillURI: felt*) = alloc();
    // ---------------------------- add json starter ---------------------------- //
    assert pillURI[0] = JSON_START;
    // -------------------------------- add name -------------------------------- //
    assert pillURI[1] = SLOT1;
    // get pill data
    let (local price: Uint256, local ing: SPillAttr, local bg: SPillAttr) = _get_pill_data(tokenId);
    let (local encode_num) = interger_to_ascii(tokenId.low);
    // ------------------------- add pill number to name ------------------------ //
    assert pillURI[2] = encode_num;
    // ----------------------------- add description ---------------------------- //
    assert pillURI[3] = DESC1_1;
    assert pillURI[4] = DESC1_2;
    assert pillURI[5] = DESC1_3;
    // ---------------------------- add image header ---------------------------- //
    assert pillURI[6] = IMAGE_START;
    // ----------------------- add baseURI to image header ---------------------- //
    // get baseURI length
    let (local base_len) = starkpill_Metadata_base_token_uri_len.read();
    _starkpill_Metadata_getBaseURI(base_len, &pillURI[7]);
    // ----------------------------- add image file ----------------------------- //
    assert pillURI[base_len + 7] = STARKPILL_FILE;
    // ---------------- add ingredient file number to image link ---------------- //
    assert pillURI[base_len + 8] = ing.file;
    // ----------------- add background file number to image link --------------- //
    assert pillURI[base_len + 9] = bg.file;
    // -------------------------- add image link ender -------------------------- //
    assert pillURI[base_len + 10] = IMAGE_END;
    // ----------------------- add attribute array starter ---------------------- //
    assert pillURI[base_len + 11] = ATTR_START;
    // ----------------------------- add first trait ---------------------------- //
    // {"trait type" : "Medical Bill"
    assert pillURI[base_len + 12] = FIRST_TRAIT;
    assert pillURI[base_len + 13] = ATTR1;
    // ,"value":{val}
    assert pillURI[base_len + 14] = VALUE;
    let (encode_eth) = interger_to_ascii(price.low);
    assert pillURI[base_len + 15] = encode_eth;
    // ----------------------------- add next trait ----------------------------- //
    // },{"trait type" : "Ingredient"
    assert pillURI[base_len + 16] = NEXT_TRAIT;
    assert pillURI[base_len + 17] = ATTR2;
    // ,"value":{val}
    assert pillURI[base_len + 18] = VALUE;
    assert pillURI[base_len + 19] = ing.attr;
    // ----------------------------- add next trait ----------------------------- //
    // },{"trait type" : "Background"
    assert pillURI[base_len + 20] = NEXT_TRAIT;
    assert pillURI[base_len + 21] = ATTR3;
    // ,"value":{val}
    assert pillURI[base_len + 22] = VALUE;
    assert pillURI[base_len + 23] = bg.attr;
    // ----------------------------- get fame levels ---------------------------- //
    let (fame: Uint256, defame: Uint256) = _get_pill_fame(tokenId);
    let (encode_fame) = interger_to_ascii(fame.low);
    let (encode_defame) = interger_to_ascii(defame.low);
    // ----------------------------- add next trait ----------------------------- //
    // },{"trait type" : "Fame"
    assert pillURI[base_len + 24] = NEXT_TRAIT;
    assert pillURI[base_len + 25] = ATTR4;
    // ,"value":{val}
    assert pillURI[base_len + 26] = VALUE;
    assert pillURI[base_len + 27] = encode_fame;
    // ----------------------------- add next trait ----------------------------- //
    // },{"trait type" : "DeFame"
    assert pillURI[base_len + 28] = NEXT_TRAIT;
    assert pillURI[base_len + 29] = ATTR5;
    // ,"value":{val}
    assert pillURI[base_len + 30] = VALUE;
    assert pillURI[base_len + 31] = encode_defame;
    // -------------------------------- end json -------------------------------- //
    assert pillURI[base_len + 32] = JSON_END;
    // ----------------------------- get arr length ----------------------------- //
    tempvar pillURI_len = base_len + 33;
    return (pillURI_len, pillURI);
}

func _starkpill_Metadata_generateIngredientJson{
    bitwise_ptr: BitwiseBuiltin*, syscall_ptr: felt*, range_check_ptr, pedersen_ptr: HashBuiltin*
}(tokenId: Uint256) -> (arr_len: felt, arr: felt*) {
    alloc_locals;
    let (local token_uri: felt*) = alloc();
    // ---------------------------- add json starter ---------------------------- //
    assert token_uri[0] = JSON_START;
    // -------------------------------- add name -------------------------------- //
    assert token_uri[1] = SLOT2;
    // get ingredient data
    let (local meta: SPillAttr) = _get_ingredient_data(tokenId);
    let (local encode_num) = interger_to_ascii(tokenId.low);
    // --------------------------- add number to name --------------------------- //
    assert token_uri[2] = encode_num;
    // ----------------------------- add description ---------------------------- //
    assert token_uri[3] = DESC2_1;
    assert token_uri[4] = DESC2_2;
    assert token_uri[5] = DESC2_3;
    // ---------------------------- add image header ---------------------------- //
    assert token_uri[6] = IMAGE_START;
    // ----------------------- add baseURI to imageHeader ----------------------- //
    let (local base_len) = starkpill_Metadata_base_token_uri_len.read();
    _starkpill_Metadata_getBaseURI(base_len, &token_uri[7]);
    // ----------------------------- add image file ----------------------------- //
    assert token_uri[base_len + 7] = INGREDIENT_FILE;
    // ----------------------------- add file number ---------------------------- //
    assert token_uri[base_len + 8] = meta.file;
    // ------------------------------ add image end ----------------------------- //
    assert token_uri[base_len + 9] = IMAGE_END;
    // --------------------------- add attribute start -------------------------- //
    assert token_uri[base_len + 10] = ATTR_START;
    // ----------------------------- add first trait ---------------------------- //
    assert token_uri[base_len + 11] = FIRST_TRAIT;
    assert token_uri[base_len + 12] = ATTR2;
    assert token_uri[base_len + 13] = VALUE;
    assert token_uri[base_len + 14] = meta.attr;
    // -------------------------------- end json -------------------------------- //
    assert token_uri[base_len + 15] = JSON_END;
    // ----------------------------- get arr length ----------------------------- //
    tempvar token_uri_len = base_len + 16;
    return (token_uri_len, token_uri);
}

func _starkpill_Metadata_generateBackgroundJson{
    bitwise_ptr: BitwiseBuiltin*, syscall_ptr: felt*, range_check_ptr, pedersen_ptr: HashBuiltin*
}(tokenId: Uint256) -> (arr_len: felt, arr: felt*) {
    alloc_locals;
    let (local token_uri: felt*) = alloc();
    // ---------------------------- add json starter ---------------------------- //
    assert token_uri[0] = JSON_START;
    // -------------------------------- add name -------------------------------- //
    assert token_uri[1] = SLOT3;
    // get background data
    let (local meta: SPillAttr) = _get_background_data(tokenId);
    let (local encode_num) = interger_to_ascii(tokenId.low);
    // --------------------------- add number to name --------------------------- //
    assert token_uri[2] = encode_num;
    // ----------------------------- add description ---------------------------- //
    assert token_uri[3] = DESC2_1;
    assert token_uri[4] = DESC2_2;
    assert token_uri[5] = DESC2_3;
    // ---------------------------- add image header ---------------------------- //
    assert token_uri[6] = IMAGE_START;
    // ----------------------- add baseURI to imageHeader ----------------------- //
    let (local base_len) = starkpill_Metadata_base_token_uri_len.read();
    _starkpill_Metadata_getBaseURI(base_len, &token_uri[7]);
    // ----------------------------- add image file ----------------------------- //
    assert token_uri[base_len + 7] = BACKGROUND_FILE;
    // ----------------------------- add file number ---------------------------- //
    assert token_uri[base_len + 8] = meta.file;
    // ------------------------------ add image end ----------------------------- //
    assert token_uri[base_len + 9] = IMAGE_END;
    // --------------------------- add attribute start -------------------------- //
    assert token_uri[base_len + 10] = ATTR_START;
    // ----------------------------- add first trait ---------------------------- //
    assert token_uri[base_len + 11] = FIRST_TRAIT;
    assert token_uri[base_len + 12] = ATTR3;
    assert token_uri[base_len + 13] = VALUE;
    assert token_uri[base_len + 14] = meta.attr;
    // -------------------------------- end json -------------------------------- //
    assert token_uri[base_len + 15] = JSON_END;
    // ----------------------------- get arr length ----------------------------- //
    tempvar token_uri_len = base_len + 16;
    return (token_uri_len, token_uri);
}
// -------------------------------------------------------------------------- //
//                                  internals                                 //
// -------------------------------------------------------------------------- //

func _starkpill_Metadata_getBaseURI{
    syscall_ptr: felt*, range_check_ptr, pedersen_ptr: HashBuiltin*
}(baseURI_len: felt, baseURI: felt*) {
    if (baseURI_len == 0) {
        return ();
    }

    let (base) = starkpill_Metadata_base_token_uri.read(baseURI_len);
    assert [baseURI] = base;
    return _starkpill_Metadata_getBaseURI(baseURI_len=baseURI_len - 1, baseURI=baseURI + 1);
}

func _starkpill_Metadata_setBaseTokenURI{
    syscall_ptr: felt*, range_check_ptr, pedersen_ptr: HashBuiltin*
}(tokenURI_len: felt, tokenURI: felt*) {
    if (tokenURI_len == 0) {
        return ();
    }

    starkpill_Metadata_base_token_uri.write(index=tokenURI_len, value=[tokenURI]);
    return _starkpill_Metadata_setBaseTokenURI(
        tokenURI_len=tokenURI_len - 1, tokenURI=tokenURI + 1
    );
}
