%lang starknet
// -------------------------------------------------------------------------- //
//                            contract name/symbol                            //
// -------------------------------------------------------------------------- //
const NAME = 'GetTestPilled';
const SYMBOL = 'TPILL';
// -------------------------------------------------------------------------- //
//                             attribute Ids Name                             //
// -------------------------------------------------------------------------- //
// "Medical Bill" -> 14
const ATTR1 = 695733874414010794109766866856994;
// "Ingredient" -> 12
const ATTR2 = 10611263287328460616261071906;
// "Background" -> 12
const ATTR3 = 10602739341536079822701093922;
// "Fame" -> 6
const ATTR4 = '"Fame"';
// "DeFame" -> 8
const ATTR5 = '"DeFame"';
// -------------------------------------------------------------------------- //
//                                 slot names                                 //
// -------------------------------------------------------------------------- //
// {"name":"TestPill # -> 20
const SLOT1 = 2745991037704434981862122315935044568424914979;
// {"name":"PillIngredient # -> 25
const SLOT2 = 772927763385525938504078964371680925585675612653512268455971;
// {"name":"PillBackground # -> 25
const SLOT3 = 772927763385525938504078964371678743455552763170360914092067;

// -------------------------------------------------------------------------- //
//                              Description const                             //
// -------------------------------------------------------------------------- //
// -------------------------------- starkpill ------------------------------- //
// ","description":"a ERC2114{space} -> 27
const DESC1_1 = 14057709894346565514766591442373866657621994583932519898200224800;
// test run{space} -> 23
const DESC1_2 = 2147132626853168508448;
// for starkpills",", -> 13
const DESC1_3 = 136159915287086273354591784541128696364;

// ----------------------- pill ingredient/background ----------------------- //
const DESC2_1 = '","description":"an ';
const DESC2_2 = 'equippable ERC2114 ';
const DESC2_3 = 'token for TestPills",';
// -------------------------------------------------------------------------- //
//                               metadata const                               //
// -------------------------------------------------------------------------- //
// data:application/json, -> 22
const JSON_START = 37556871985679581542840396273993309325169359621942828;
// "image":"https://arweave.net/ -> 29
const IMAGE_START = 927740973829518823451220790258413788144013612784869718513070840837167;
// .png", -> 6
const IMAGE_END = 51060423467564;
// "attributes":[ -> 14
const ATTR_START = 697323099324868568365382768933467;
// {"trait_type": -> 14
const FIRST_TRAIT = 2497466177313338004234581594939962;
// },{"trait_type": -> 16
const NEXT_TRAIT = 166384458001067329866635458955123696186;
// ,"value": -> 9
const VALUE = 814140018606215602746;
// }]} -> 3
const JSON_END = 8215933;
// ------------------------------ file headers ------------------------------ //
const STARKPILL_FILE = '/TestPill/pill_';
const INGREDIENT_FILE = '/PillIngredient/ing_';
const BACKGROUND_FILE = '/PillBackground/bg_';