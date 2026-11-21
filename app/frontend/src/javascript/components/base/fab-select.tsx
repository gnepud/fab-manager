import { ReactNode } from 'react';
import ReactSelect, { GroupBase, Props } from 'react-select';
import { useTranslation } from 'react-i18next';

/**
 * A select with a localized default placeholder.
 */
export const FabSelect = <Option, IsMulti extends boolean = false, Group extends GroupBase<Option> = GroupBase<Option>>({ placeholder, ...props }: Props<Option, IsMulti, Group>) => {
  const translatedPlaceholder = useSelectPlaceholder(placeholder);
  return <ReactSelect {...props} placeholder={translatedPlaceholder} />;
};

export function useSelectPlaceholder (placeholder?: ReactNode) {
  const { t } = useTranslation('shared');
  return placeholder === undefined ? t('app.shared.fab_select.placeholder') : placeholder;
}
