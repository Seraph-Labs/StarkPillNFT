%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin, SignatureBuiltin, BitwiseBuiltin
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.bool import TRUE, FALSE
from starkware.cairo.common.uint256 import Uint256, uint256_check, uint256_eq, uint256_le
from starkware.cairo.common.math import assert_not_zero, assert_not_equal
from starkware.starknet.common.syscalls import get_caller_address, get_contract_address
from starkware.cairo.common.math_cmp import is_not_zero, is_le
from openzeppelin.security.safemath.library import SafeUint256
// ------------------------------- interfaces ------------------------------- //
from testpill.interfaces.IERC20 import IERC20
// ------------------------------- token libs ------------------------------- //
from SeraphLabs.tokens.ERC2114.library import (
    _ERC2114_scalar_transfer,
    ERC2114_createAttribute,
    ERC2114_tokenAttribute_len,
    _ERC2114_addAttribute,
    _ERC2114_attrIdName,
    _ERC2114_attributeAmmount,
    _ERC2114_attributeValue,
    ERC2114_tokenBalanceOf,
)

from SeraphLabs.tokens.ERC2114.enumerable.library import (
    ERC2114Enumerable_scalarTransferFrom,
    ERC2114Enumerable_scalarRemoveFrom,
    _ERC2114Enumerable_scalarTransferFrom,
)
from SeraphLabs.tokens.ERC721S.library import ERC721S_ownerOf
from SeraphLabs.tokens.ERC3525.library import (
    ERC3525_slotOf,
    ERC3525_mint,
    ERC3525_supplyOfSlot,
    _slot_of,
)
from SeraphLabs.tokens.libs.tokenCounter import TokenCounter
// --------------------------------- models --------------------------------- //
from SeraphLabs.models.StringObject import StrObj
from testpill.contracts.testpillV6.Pharmacy.library import PillBottle, SPillAttr, Pharmacy
// -------------------------------- constants ------------------------------- //
from testpill.utils.pillConstants.library import ATTR1, ATTR2, ATTR3
// -------------------------------------------------------------------------- //
//                                   events                                   //
// -------------------------------------------------------------------------- //
@event
func PrescriptionUpdated(
    owner: felt,
    tokenId: Uint256,
    medicalBill: Uint256,
    old_prescription: PillBottle,
    new_prescription: PillBottle,
) {
}

@event
func PremiumStarkPillMinted(minter: felt, pill: Uint256, price: Uint256) {
}

@event
func CurrenyUpdated(old_currency: felt, new_currency: felt) {
}

// -------------------------------------------------------------------------- //
//                                   storage                                  //
// -------------------------------------------------------------------------- //
@storage_var
func starkpill_currency() -> (currency: felt) {
}

@storage_var
func starkpill_wallet() -> (wallet: felt) {
}

@storage_var
func starkpill_minPrice() -> (price: Uint256) {
}

@storage_var
func starkpill_pillStorage(tokenId: Uint256) -> (pill: PillBottle) {
}

// ! deprecated no longer in use
@storage_var
func starkpill_typeCounter(tokenId: Uint256) -> (number: Uint256) {
}

namespace StarkPill {
    // -------------------------------------------------------------------------- //
    //                                 constructor                                //
    // -------------------------------------------------------------------------- //
    func initializer{syscall_ptr: felt*, range_check_ptr, pedersen_ptr: HashBuiltin*}(
        currency: felt, wallet: felt
    ) {
        setCurrency(currency);
        starkpill_wallet.write(wallet);
        starkpill_minPrice.write(Uint256(1000000000000000, 0));
        ERC2114_createAttribute(Uint256(1, 0), StrObj(ATTR1, 14));
        ERC2114_createAttribute(Uint256(2, 0), StrObj(ATTR2, 12));
        ERC2114_createAttribute(Uint256(3, 0), StrObj(ATTR3, 12));
        return ();
    }
    // -------------------------------------------------------------------------- //
    //                                    view                                    //
    // -------------------------------------------------------------------------- //
    func getPrescription{
        bitwise_ptr: BitwiseBuiltin*,
        syscall_ptr: felt*,
        range_check_ptr,
        pedersen_ptr: HashBuiltin*,
    }(tokenId: Uint256) -> (ingredient: Uint256, Background: Uint256, price: Uint256) {
        alloc_locals;
        let (slot: Uint256) = ERC3525_slotOf(tokenId);
        // check if tokenId is pill
        let (is_pill) = uint256_eq(slot, Uint256(1, 0));
        // if false return tokenId price only
        if (is_pill == FALSE) {
            let (price: Uint256) = _ERC2114_attributeAmmount(tokenId, Uint256(1, 0));
            return (Uint256(0, 0), Uint256(0, 0), price);
        }

        let (pill: PillBottle) = starkpill_pillStorage.read(tokenId);
        let (price: Uint256) = _get_total_price(tokenId, pill.ing, pill.BG);
        return (pill.ing, pill.BG, price);
    }

    func getMinimumMintPrice{syscall_ptr: felt*, range_check_ptr, pedersen_ptr: HashBuiltin*}() -> (
        price: Uint256
    ) {
        let (price: Uint256) = starkpill_minPrice.read();
        return (price,);
    }

    func getIngredientPremium{syscall_ptr: felt*, range_check_ptr, pedersen_ptr: HashBuiltin*}(
        index: felt
    ) -> (price: Uint256) {
        let (price: Uint256) = Pharmacy.getIngredientPrice(index);
        return (price,);
    }

    func getBackgroundPremium{syscall_ptr: felt*, range_check_ptr, pedersen_ptr: HashBuiltin*}(
        index: felt
    ) -> (price: Uint256) {
        let (price: Uint256) = Pharmacy.getBackgroundPrice(index);
        return (price,);
    }

    func getStock{syscall_ptr: felt*, range_check_ptr, pedersen_ptr: HashBuiltin*}(
        typeIndex: felt, index: felt
    ) -> (start_ammount: felt, ammount_left: felt) {
        return Pharmacy.getStock(typeIndex, index);
    }

    // -------------------------------------------------------------------------- //
    //                                  externals                                 //
    // -------------------------------------------------------------------------- //

    func setIngredientPremium{syscall_ptr: felt*, range_check_ptr, pedersen_ptr: HashBuiltin*}(
        index: felt, price: Uint256
    ) {
        Pharmacy.setIngPrice(index, price);
        return ();
    }

    func setBackgroundPremium{syscall_ptr: felt*, range_check_ptr, pedersen_ptr: HashBuiltin*}(
        index: felt, price: Uint256
    ) {
        Pharmacy.setBgPrice(index, price);
        return ();
    }

    func mintPill{
        bitwise_ptr: BitwiseBuiltin*,
        syscall_ptr: felt*,
        range_check_ptr,
        pedersen_ptr: HashBuiltin*,
    }(ingredientType: felt, backgroundType: felt, price: Uint256) {
        alloc_locals;
        // assert caller is not zero address
        let (local caller) = get_caller_address();
        with_attr error_message("starkpill: caller is invalid") {
            assert_not_zero(caller);
        }
        // get minimum price to mint, total & individual price of all traits
        let (min_price: Uint256, attr_price: Uint256) = _get_mint_cost(
            ingredientType, backgroundType
        );

        // assert price is more than or equal to min price
        with_attr error_message("starkpill: minimum price not met") {
            let (can_mint) = uint256_le(min_price, price);
            assert can_mint = TRUE;
        }

        // get pill_base price price - attr_price
        let (pill_price: Uint256) = SafeUint256.sub_le(price, attr_price);

        let (local contract_addr) = get_contract_address();
        let (currency) = starkpill_currency.read();
        let (wallet) = starkpill_wallet.read();

        // -------------------------- step 1: transfer eth -------------------------- //
        // assert transfer was successful
        with_attr error_message("starkpill: eth failed to send") {
            // transfer eth to contract
            let (success) = IERC20.transferFrom(currency, caller, wallet, price);
            assert_not_zero(success);
        }

        // -------------------------- step 2 : mint tokens -------------------------- //
        // mint empty pill with price as attribute
        let (pillId: Uint256) = _mint_empty_pill(caller, pill_price);
        // mint ingredient depending on the ingredient Type
        let (ingId: Uint256) = _mint_add_ingredient(caller, contract_addr, ingredientType, pillId);
        // mint background depending on the background Type
        let (bgId: Uint256) = _mint_add_background(caller, contract_addr, backgroundType, pillId);

        // -------------------- step 3: update starkpill storage -------------------- //
        tempvar new_pill: PillBottle = PillBottle(ingId, bgId);
        starkpill_pillStorage.write(pillId, new_pill);
        // emit event
        PrescriptionUpdated.emit(
            caller, pillId, price, PillBottle(Uint256(0, 0), Uint256(0, 0)), new_pill
        );
        return ();
    }

    func changePrescription{
        bitwise_ptr: BitwiseBuiltin*,
        syscall_ptr: felt*,
        range_check_ptr,
        pedersen_ptr: HashBuiltin*,
    }(tokenId: Uint256, ingredientId: Uint256, backgroundId: Uint256) {
        alloc_locals;
        let (local caller) = get_caller_address();
        with_attr error_message("starkpill: invalid caller") {
            assert_not_zero(caller);
        }

        // ensure caller owns token
        let (local owner) = ERC721S_ownerOf(tokenId);
        with_attr error_message("starkpill: caller does not own tokenId") {
            assert caller = owner;
        }

        // ensure that tokenId is of slot pill
        let (pill_slot: Uint256, _) = _slot_of(tokenId);
        with_attr error_message("starpill: tokenId must be of slotId 1") {
            let (is_pill) = uint256_eq(pill_slot, Uint256(1, 0));
            assert is_pill = TRUE;
        }

        let (local cur_pill: PillBottle) = starkpill_pillStorage.read(tokenId);
        // ensure not changing to the same prescription
        with_attr error_message("starkpill: prescription cant be the same") {
            let (same_ing) = uint256_eq(cur_pill.ing, ingredientId);
            let (same_bg) = uint256_eq(cur_pill.BG, backgroundId);
            assert same_ing * same_bg = 0;
        }

        _change_pill_ingredient(caller, tokenId, ingredientId, cur_pill.ing);
        _change_pill_background(caller, tokenId, backgroundId, cur_pill.BG);

        tempvar new_pill: PillBottle = PillBottle(ingredientId, backgroundId);
        // edit starpill storage
        starkpill_pillStorage.write(tokenId, new_pill);
        // get pill Id price
        let (price: Uint256) = _ERC2114_attributeAmmount(tokenId, Uint256(1, 0));
        // emit event
        PrescriptionUpdated.emit(caller, tokenId, price, cur_pill, new_pill);
        return ();
    }

    func scalarTransferFrom{
        bitwise_ptr: BitwiseBuiltin*,
        syscall_ptr: felt*,
        range_check_ptr,
        pedersen_ptr: HashBuiltin*,
    }(from_: felt, tokenId: Uint256, to: Uint256) {
        alloc_locals;
        // scalar transfer tokenId
        ERC2114Enumerable_scalarTransferFrom(from_, tokenId, to);

        let (local to_slot: Uint256, _) = _slot_of(to);
        let (is_pill) = uint256_eq(to_slot, Uint256(1, 0));
        // if to tokenId is not pill just skip
        if (is_pill == FALSE) {
            return ();
        }

        let (local cur_pill: PillBottle) = starkpill_pillStorage.read(to);
        let (no_ing) = uint256_le(cur_pill.ing, Uint256(0, 0));
        let (no_bg) = uint256_le(cur_pill.BG, Uint256(0, 0));

        let (local from_slot: Uint256, _) = _slot_of(tokenId);
        let (is_ing) = uint256_eq(from_slot, Uint256(2, 0));
        let (is_bg) = uint256_eq(from_slot, Uint256(3, 0));

        // if to is a pill and has no ingredient
        // and tokenId is a ingredient
        // update to Prescription
        if (no_ing == TRUE and is_ing == TRUE) {
            tempvar new_pill: PillBottle = PillBottle(tokenId, cur_pill.BG);
            // get current price, using current pillid, equiiped ingId and BgId
            let (price: Uint256) = _get_total_price(to, tokenId, cur_pill.BG);
            // edit starpill storage
            starkpill_pillStorage.write(to, new_pill);
            // emit event
            PrescriptionUpdated.emit(from_, to, price, cur_pill, new_pill);
            return ();
        }

        // if to is a pill and has no background
        // and tokenId is a background
        // update to Prescription
        if (no_bg == TRUE and is_bg == TRUE) {
            tempvar new_pill: PillBottle = PillBottle(cur_pill.ing, tokenId);
            // get current price, using current pillid, equiiped ingId and BgId
            let (price: Uint256) = _get_total_price(to, cur_pill.ing, tokenId);
            // edit starpill storage
            starkpill_pillStorage.write(to, new_pill);
            // emit event
            PrescriptionUpdated.emit(from_, to, price, cur_pill, new_pill);
            return ();
        }

        return ();
    }

    func scalarRemoveFrom{
        bitwise_ptr: BitwiseBuiltin*,
        syscall_ptr: felt*,
        range_check_ptr,
        pedersen_ptr: HashBuiltin*,
    }(from_: Uint256, tokenId: Uint256) {
        alloc_locals;
        // scalar remove tokenId
        ERC2114Enumerable_scalarRemoveFrom(from_, tokenId);

        let (local from_slot: Uint256, _) = _slot_of(from_);
        let (is_pill) = uint256_eq(from_slot, Uint256(1, 0));
        // if to from_ tokenId is not pill just skip
        if (is_pill == FALSE) {
            return ();
        }

        let (local owner) = ERC721S_ownerOf(from_);
        let (local cur_pill: PillBottle) = starkpill_pillStorage.read(from_);
        let (is_ing) = uint256_eq(cur_pill.ing, tokenId);
        let (is_bg) = uint256_eq(cur_pill.BG, tokenId);

        if (is_ing == TRUE) {
            tempvar new_pill: PillBottle = PillBottle(Uint256(0, 0), cur_pill.BG);
            // get current price, using current pillid, equiiped ingId and BgId
            let (price: Uint256) = _get_total_price(from_, Uint256(0, 0), cur_pill.BG);
            // edit starpill storage
            starkpill_pillStorage.write(from_, new_pill);
            // emit event
            PrescriptionUpdated.emit(owner, from_, price, cur_pill, new_pill);
            return ();
        }

        if (is_bg == TRUE) {
            tempvar new_pill: PillBottle = PillBottle(cur_pill.ing, Uint256(0, 0));
            // get current price, using current pillid, equiiped ingId and BgId
            let (price: Uint256) = _get_total_price(from_, cur_pill.ing, Uint256(0, 0));
            // edit starpill storage
            starkpill_pillStorage.write(from_, new_pill);
            // emit event
            PrescriptionUpdated.emit(owner, from_, price, cur_pill, new_pill);
            return ();
        }

        return ();
    }

    func setCurrency{syscall_ptr: felt*, range_check_ptr, pedersen_ptr: HashBuiltin*}(
        currency: felt
    ) {
        let (old_currency) = starkpill_currency.read();
        starkpill_currency.write(currency);
        CurrenyUpdated.emit(old_currency, currency);
        return ();
    }

    func updateStock{syscall_ptr: felt*, range_check_ptr, pedersen_ptr: HashBuiltin*}(
        typeIndex: felt, index: felt, ammount: felt
    ) {
        Pharmacy.addStock(typeIndex, index, ammount);
        return ();
    }
}
// -------------------------------------------------------------------------- //
//                                  internals                                 //
// -------------------------------------------------------------------------- //
func _get_pill_data{
    bitwise_ptr: BitwiseBuiltin*, syscall_ptr: felt*, range_check_ptr, pedersen_ptr: HashBuiltin*
}(tokenId: Uint256) -> (price: Uint256, ing: SPillAttr, bg: SPillAttr) {
    alloc_locals;
    // WARNING: assumes tokenID is of type pill
    // and does not check if tokenId exist
    let (pill: PillBottle) = starkpill_pillStorage.read(tokenId);
    let (price: Uint256) = _get_total_price(tokenId, pill.ing, pill.BG);
    let (ing: SPillAttr) = _get_ingredient_data(pill.ing);
    let (bg: SPillAttr) = _get_background_data(pill.BG);
    return (price, ing, bg);
}

func _get_ingredient_data{syscall_ptr: felt*, range_check_ptr, pedersen_ptr: HashBuiltin*}(
    tokenId: Uint256
) -> (res: SPillAttr) {
    let (is_zero) = uint256_le(tokenId, Uint256(0, 0));
    if (is_zero == TRUE) {
        // if tokenId is zero get ingredient data at zero index
        // as it means no ingredient equipped
        let (ing_data: SPillAttr) = Pharmacy.getPillIngredient(0);
        return (ing_data,);
    } else {
        // get tokenId attr value which stores the index in StrObj.val
        let (temp_str: StrObj) = _ERC2114_attributeValue(tokenId=tokenId, attrId=Uint256(2, 0));
        let (ing_data: SPillAttr) = Pharmacy.getPillIngredient(temp_str.val);

        return (ing_data,);
    }
}

func _get_background_data{syscall_ptr: felt*, range_check_ptr, pedersen_ptr: HashBuiltin*}(
    tokenId: Uint256
) -> (res: SPillAttr) {
    let (is_zero) = uint256_le(tokenId, Uint256(0, 0));
    if (is_zero == TRUE) {
        // if tokenId is zero get background data at zero index
        // as it means no background equipped
        let (bg_data: SPillAttr) = Pharmacy.getPillBackground(0);
        return (bg_data,);
    } else {
        // get tokenId attr value which stores the index in StrObj.val
        let (temp_str: StrObj) = _ERC2114_attributeValue(tokenId=tokenId, attrId=Uint256(3, 0));
        let (bg_data: SPillAttr) = Pharmacy.getPillBackground(temp_str.val);
        return (bg_data,);
    }
}

// -------------------------------------------------------------------------- //
//                                  private                                   //
// -------------------------------------------------------------------------- //
func _mint_empty_pill{
    bitwise_ptr: BitwiseBuiltin*, syscall_ptr: felt*, range_check_ptr, pedersen_ptr: HashBuiltin*
}(caller: felt, price: Uint256) -> (pill_id: Uint256) {
    alloc_locals;
    // mint token
    ERC3525_mint(caller, Uint256(1, 0), Uint256(1, 0), Uint256(0, 0));
    // get minted token
    let (local tokenId: Uint256) = TokenCounter.current();
    // add attribute to tokenId at index 0
    _ERC2114_addAttribute(
        tokenId=tokenId, attrId=Uint256(1, 0), value=StrObj(0, 0), ammount=price, index=0
    );
    // increase minted tokenId attrId len by 1
    ERC2114_tokenAttribute_len.write(tokenId, 1);
    return (tokenId,);
}

func _mint_add_ingredient{
    bitwise_ptr: BitwiseBuiltin*, syscall_ptr: felt*, range_check_ptr, pedersen_ptr: HashBuiltin*
}(caller: felt, contract_addr: felt, index: felt, pillId: Uint256) -> (ing_id: Uint256) {
    alloc_locals;
    if (index == 0) {
        return (Uint256(0, 0),);
    }
    // asset valid index
    Pharmacy.assertValidIngredientType(index);
    // clear stock if there is any
    Pharmacy.clearStock(1, index);
    // ---------------------------------- mint ---------------------------------- //
    // mint ingredient straight to contract
    // to skip external scalarTransfer assertions
    ERC3525_mint(contract_addr, Uint256(1, 0), Uint256(2, 0), Uint256(0, 0));
    // get minted token
    let (local tokenId: Uint256) = TokenCounter.current();
    // ------------------------------ add attribute ----------------------------- //
    // add ingredient type attribute to tokenId at index 0
    _ERC2114_addAttribute(
        tokenId=tokenId,
        attrId=Uint256(2, 0),
        value=StrObj(index, 1),
        ammount=Uint256(1, 0),
        index=0,
    );
    // get ing price
    let (price: Uint256) = Pharmacy.getIngredientPrice(index);
    let (no_price) = uint256_le(price, Uint256(0, 0));

    // if no premium price only increase attr len by 1
    // else increase by 2 and add medical bill trait
    if (no_price == TRUE) {
        // increase minted tokenId attrId len by 1
        ERC2114_tokenAttribute_len.write(tokenId, 1);
        tempvar syscall_ptr = syscall_ptr;
        tempvar pedersen_ptr = pedersen_ptr;
        tempvar range_check_ptr = range_check_ptr;
    } else {
        _ERC2114_addAttribute(
            tokenId=tokenId, attrId=Uint256(1, 0), value=StrObj(0, 0), ammount=price, index=1
        );
        // increase minted tokenId attrId len by 2
        ERC2114_tokenAttribute_len.write(tokenId, 2);
        tempvar syscall_ptr = syscall_ptr;
        tempvar pedersen_ptr = pedersen_ptr;
        tempvar range_check_ptr = range_check_ptr;
    }

    // ----------------------------- scalar transfer ---------------------------- //
    // internal scalar transfer and
    // internal enumerable scalar transfer to index based on pillId current balance
    let (balance: Uint256) = ERC2114_tokenBalanceOf(pillId);
    _ERC2114_scalar_transfer(caller, 0, tokenId, pillId);
    _ERC2114Enumerable_scalarTransferFrom(tokenId, pillId, balance);
    return (tokenId,);
}

func _mint_add_background{
    bitwise_ptr: BitwiseBuiltin*, syscall_ptr: felt*, range_check_ptr, pedersen_ptr: HashBuiltin*
}(caller: felt, contract_addr: felt, index: felt, pillId: Uint256) -> (bg_id: Uint256) {
    alloc_locals;
    if (index == 0) {
        return (Uint256(0, 0),);
    }
    // asset valid index
    Pharmacy.assertValidBackgroundType(index);
    // clear stock if there is any
    Pharmacy.clearStock(2, index);
    // ---------------------------------- mint ---------------------------------- //
    // mint background straight to contract
    // to skip external scalarTransfer assertions
    ERC3525_mint(contract_addr, Uint256(1, 0), Uint256(3, 0), Uint256(0, 0));
    // get minted token
    let (local tokenId: Uint256) = TokenCounter.current();
    // ------------------------------ add attribute ----------------------------- //
    // add background type attribute to tokenId at index 0
    _ERC2114_addAttribute(
        tokenId=tokenId,
        attrId=Uint256(3, 0),
        value=StrObj(index, 1),
        ammount=Uint256(1, 0),
        index=0,
    );
    // get background price
    let (price: Uint256) = Pharmacy.getBackgroundPrice(index);
    let (no_price) = uint256_le(price, Uint256(0, 0));

    // if no premium price only increase attr len by 1
    // else increase by 2 and add medical bill trait
    if (no_price == TRUE) {
        // increase minted tokenId attrId len by 1
        ERC2114_tokenAttribute_len.write(tokenId, 1);
        tempvar syscall_ptr = syscall_ptr;
        tempvar pedersen_ptr = pedersen_ptr;
        tempvar range_check_ptr = range_check_ptr;
    } else {
        _ERC2114_addAttribute(
            tokenId=tokenId, attrId=Uint256(1, 0), value=StrObj(0, 0), ammount=price, index=1
        );
        // increase minted tokenId attrId len by 2
        ERC2114_tokenAttribute_len.write(tokenId, 2);
        tempvar syscall_ptr = syscall_ptr;
        tempvar pedersen_ptr = pedersen_ptr;
        tempvar range_check_ptr = range_check_ptr;
    }

    // ----------------------------- scalar transfer ---------------------------- //
    // internal scalar transfer and
    // internal enumerable scalar transfer to index based on pillId current balance
    let (balance: Uint256) = ERC2114_tokenBalanceOf(pillId);
    _ERC2114_scalar_transfer(caller, 0, tokenId, pillId);
    _ERC2114Enumerable_scalarTransferFrom(tokenId, pillId, balance);
    return (tokenId,);
}

func _change_pill_ingredient{
    bitwise_ptr: BitwiseBuiltin*, syscall_ptr: felt*, range_check_ptr, pedersen_ptr: HashBuiltin*
}(caller: felt, tokenId: Uint256, ingredientId: Uint256, cur_ingredientId: Uint256) {
    alloc_locals;

    let (local no_ing) = uint256_le(cur_ingredientId, Uint256(0, 0));
    let (local zero_ing) = uint256_le(ingredientId, Uint256(0, 0));

    // if both ingIds are equal skip and return
    let (is_equal) = uint256_eq(ingredientId, cur_ingredientId);
    if (is_equal == TRUE) {
        return ();
    }

    // if ingredientId is 0 scalarRemove current ingredient from tokenId
    if (zero_ing == TRUE) {
        // remove cur_ingredient
        ERC2114Enumerable_scalarRemoveFrom(tokenId, cur_ingredientId);
        return ();
    }

    // ensure that ingredient is of slot ing
    // use internal slot_of function to avoid extra assertion checks
    // that will be done in scalar remove/transfer
    let (i_slot: Uint256, _) = _slot_of(ingredientId);
    with_attr error_message("starkpill: ingredientId is not an Ingredient") {
        let (is_ing) = uint256_eq(i_slot, Uint256(2, 0));
        assert is_ing = TRUE;
    }

    // if no ingredient is TRUE transfer ingredientId to tokenId
    // else remove current ingredient and transfer new ingredientId to tokenId
    if (no_ing == TRUE) {
        // transfer ingredient
        ERC2114Enumerable_scalarTransferFrom(caller, ingredientId, tokenId);
        return ();
    } else {
        // remove cur_ingredient
        ERC2114Enumerable_scalarRemoveFrom(tokenId, cur_ingredientId);
        // transfer ingredient
        ERC2114Enumerable_scalarTransferFrom(caller, ingredientId, tokenId);
        return ();
    }
}

func _change_pill_background{
    bitwise_ptr: BitwiseBuiltin*, syscall_ptr: felt*, range_check_ptr, pedersen_ptr: HashBuiltin*
}(caller: felt, tokenId: Uint256, backgroundId: Uint256, cur_backgroundId: Uint256) {
    alloc_locals;

    let (local no_bg) = uint256_le(cur_backgroundId, Uint256(0, 0));
    let (local zero_bg) = uint256_le(backgroundId, Uint256(0, 0));

    // if both ingIds are equal skip and return
    let (is_equal) = uint256_eq(backgroundId, cur_backgroundId);
    if (is_equal == TRUE) {
        return ();
    }

    // if backgroundId is 0 scalarRemove current background from tokenId
    if (zero_bg == TRUE) {
        // remove cur_background
        ERC2114Enumerable_scalarRemoveFrom(tokenId, cur_backgroundId);
        return ();
    }

    // ensure that background is of slot BG
    // use internal slot_of function to avoid extra assertion checks
    // that will be done in scalar remove/transfer
    let (bg_slot: Uint256, _) = _slot_of(backgroundId);
    with_attr error_message("starkpill: backgroundId is not a Background") {
        let (is_bg) = uint256_eq(bg_slot, Uint256(3, 0));
        assert is_bg = TRUE;
    }

    // if no background is TRUE transfer backgroundId to tokenId
    // else remove current background and transfer new backgroundId to tokenId
    if (no_bg == TRUE) {
        // transfer background
        ERC2114Enumerable_scalarTransferFrom(caller, backgroundId, tokenId);
        return ();
    } else {
        // remove cur_background
        ERC2114Enumerable_scalarRemoveFrom(tokenId, cur_backgroundId);
        // transfer background
        ERC2114Enumerable_scalarTransferFrom(caller, backgroundId, tokenId);
        return ();
    }
}

func _get_mint_cost{syscall_ptr: felt*, range_check_ptr, pedersen_ptr: HashBuiltin*}(
    ingredientType: felt, backgroundType: felt
) -> (min_price: Uint256, attr_price: Uint256) {
    let (base_price: Uint256) = starkpill_minPrice.read();

    let (ing_price: Uint256) = Pharmacy.getIngredientPrice(ingredientType);
    let (bg_price: Uint256) = Pharmacy.getBackgroundPrice(backgroundType);

    let (attr_price: Uint256) = SafeUint256.add(ing_price, bg_price);

    let (min_price: Uint256) = SafeUint256.add(attr_price, base_price);
    return (min_price, attr_price);
}

func _get_total_price{syscall_ptr: felt*, range_check_ptr, pedersen_ptr: HashBuiltin*}(
    pillId: Uint256, ingId: Uint256, bgId: Uint256
) -> (price: Uint256) {
    // get pill,ing and bg price from attr1
    let (pill_price: Uint256) = _ERC2114_attributeAmmount(pillId, Uint256(1, 0));
    let (ing_price: Uint256) = _ERC2114_attributeAmmount(ingId, Uint256(1, 0));
    let (bg_price: Uint256) = _ERC2114_attributeAmmount(bgId, Uint256(1, 0));
    let (temp_price: Uint256) = SafeUint256.add(pill_price, ing_price);
    let (total_price: Uint256) = SafeUint256.add(temp_price, bg_price);
    return (total_price,);
}
