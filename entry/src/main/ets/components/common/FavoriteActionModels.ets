export interface FavoriteToggleTransition {
  previousValue: boolean;
  pendingValue: boolean;
}

export function beginFavoriteToggle(currentValue: boolean): FavoriteToggleTransition {
  return {
    previousValue: currentValue,
    pendingValue: !currentValue
  };
}

export function completeFavoriteToggle(
  transition: FavoriteToggleTransition,
  persistenceSucceeded: boolean
): boolean {
  return persistenceSucceeded ? transition.pendingValue : transition.previousValue;
}
