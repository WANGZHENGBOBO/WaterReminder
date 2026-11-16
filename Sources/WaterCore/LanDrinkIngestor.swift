import Foundation

public enum LanDrinkIngestor {
    public static func ingest(_ event: DrinkSyncEvent, into state: SavedState)
        -> (state: SavedState, duplicate: Bool) {
        let before = Set(state.drinks.map(\.id))
        var changed = state
        changed.drinks = DrinkSyncMerge.apply(events: [event], to: state.drinks)
        let after = Set(changed.drinks.map(\.id))
        return (changed, before == after)
    }

    public static func applyDeviceAliases(_ devices: [LanDeviceRecord], to state: SavedState)
        -> (state: SavedState, changed: Bool) {
        var changed = state
        var didChange = false
        for device in devices {
            for index in changed.drinks.indices
            where changed.drinks[index].deviceID == device.deviceID {
                if changed.drinks[index].deviceShortName != device.shortName
                    || changed.drinks[index].deviceName != device.name {
                    changed.drinks[index].deviceShortName = device.shortName
                    changed.drinks[index].deviceName = device.name
                    didChange = true
                }
            }
        }
        return (changed, didChange)
    }
}
