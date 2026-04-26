
# MiniMap

## When the current quest objective is a door (zone, house, dungeon, boat, ...), or when it is an item, the shortest-path-to-quest system does not work, shrines are not indicated on the minimap. We can't even see the marker/indicator that points directly to the quest objective.

## Bad "sellable" markers :
- When using a crafting station, the "sellable" marker is not applied on the correct item, items index seems messed up.
- Bank items are not taken into account when looking at inventory outside of bank.

## Extend the "sellable" marker :
- create a table to qualify items in regard to the playing character's class type (tank/heal/DPS)
  - for example :
    - if player is tank, only items with [Infused | Charged | Defending | ...] are interesting
    - if player is healer, only items with [Powered | Charged | Infused | ...] are interesting
    - if player is DPS, only items with [Divines | Precise | Sharpened | Nirnhoned | Bloodthirsty | ...] are interesting
- when an item does not satisfy the table, marke it as sellable
