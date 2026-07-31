# UTF-8
from copy import deepcopy
from validate_characters_v02 import CHARACTERS, WEAPONS, contract_errors

def valid():
    return {"characters": {name: {"path": f"assets/production/models/{name}.glb", "blend_source": f"tools/production_source/characters_v02/{name}.blend", "weapon": weapon} for name, weapon in CHARACTERS.items()}, "weapons": {name: {"path": f"assets/production/weapons/{name}.glb", "blend_source": f"tools/production_source/characters_v02/weapon_{name}.blend"} for name in WEAPONS}}

assert contract_errors({})
missing = valid(); del missing["characters"]["hero_ash_vanguard"]; assert contract_errors(missing)
swapped = valid(); swapped["characters"]["hero_ash_vanguard"]["weapon"] = "oathblade"; assert contract_errors(swapped)
assert not contract_errors(valid())
print("PASS validator contract rejection cases")
