/**
 * @file useAccentColor.js
 * @description A composable for managing the user's accent (brand) color throughout the app.
 * Applies the selected color instantly via CSS custom properties on document.documentElement,
 * and persists it via updateUISettings (same pattern as useFontSize).
 */

import { computed, watch } from 'vue';
import { useUISettings } from 'dashboard/composables/useUISettings';
import { useAlert } from 'dashboard/composables';
import { useI18n } from 'vue-i18n';

/**
 * Accent color presets.
 * Each entry has a name, hex value, and a label key.
 * These reflect a Meta-compliant professional palette.
 */
export const ACCENT_COLOR_PRESETS = [
    { id: 'meta-blue', hex: '#1877F2', label: 'Meta Blue' },
    { id: 'indigo', hex: '#5B5BD6', label: 'Indigo' },
    { id: 'violet', hex: '#7C3AED', label: 'Violet' },
    { id: 'teal', hex: '#0D9488', label: 'Teal' },
    { id: 'green', hex: '#16A34A', label: 'Green' },
    { id: 'rose', hex: '#E5466C', label: 'Rose' },
    { id: 'amber', hex: '#D97706', label: 'Amber' },
    { id: 'slate', hex: '#475569', label: 'Slate' },
];

export const DEFAULT_ACCENT_COLOR = ACCENT_COLOR_PRESETS[0].hex;

/**
 * Convert a hex color (#RRGGBB) to an "R G B" triplet string
 * suitable for CSS custom properties used with rgb(var(--x) / alpha).
 *
 * @param {string} hex - 6-digit hex color e.g. '#1877F2'
 * @returns {string} e.g. '24 119 242'
 */
const hexToRgbTriplet = hex => {
    const clean = hex.replace('#', '');
    const r = parseInt(clean.substring(0, 2), 16);
    const g = parseInt(clean.substring(2, 4), 16);
    const b = parseInt(clean.substring(4, 6), 16);
    return `${r} ${g} ${b}`;
};

/**
 * Derive a slightly darker shade for hover/active states (blue-10 / blue-11).
 * Simple darkening: reduce each channel by ~8%.
 *
 * @param {string} hex
 * @returns {{dark1: string, dark2: string}}
 */
const deriveShades = hex => {
    const clean = hex.replace('#', '');
    const darken = (channel, factor) =>
        Math.max(0, Math.round(parseInt(channel, 16) * factor));

    const r1 = darken(clean.substring(0, 2), 0.88);
    const g1 = darken(clean.substring(2, 4), 0.88);
    const b1 = darken(clean.substring(4, 6), 0.88);

    const r2 = darken(clean.substring(0, 2), 0.76);
    const g2 = darken(clean.substring(2, 4), 0.76);
    const b2 = darken(clean.substring(4, 6), 0.76);

    return {
        dark1: `${r1} ${g1} ${b1}`,
        dark2: `${r2} ${g2} ${b2}`,
    };
};

/**
 * Apply accent color hex to the document root CSS variables.
 * Overrides --blue-8, --blue-9 (primary), --blue-10 (hover), --blue-11 (active/text).
 * These are used by all buttons, links, focus rings, and brand elements.
 *
 * @param {string} hex - 6-digit hex color
 */
const applyAccentColorToDOM = hex => {
    const root = document.documentElement;
    const triplet = hexToRgbTriplet(hex);
    const { dark1, dark2 } = deriveShades(hex);

    root.style.setProperty('--blue-9', triplet);
    root.style.setProperty('--blue-10', dark1);
    root.style.setProperty('--blue-11', dark2);
    // Also update the solid-blue used for hover backgrounds
    root.style.setProperty('--solid-blue', hexToRgbTriplet(hex).split(' ').map((v, i) => {
        // Mix with white for a light tint
        const whites = [255, 255, 255];
        return Math.round(parseInt(v) * 0.25 + whites[i] * 0.75);
    }).join(' '));
};

/**
 * Accent color management composable.
 *
 * @returns {{ accentColorPresets, currentAccentColor, updateAccentColor, applyAccentColor }}
 */
export const useAccentColor = () => {
    const { uiSettings, updateUISettings } = useUISettings();
    const { t } = useI18n();

    /**
     * The currently saved accent color hex (falls back to Meta-blue default).
     * @type {import('vue').ComputedRef<string>}
     */
    const currentAccentColor = computed(
        () => uiSettings.value.accent_color || DEFAULT_ACCENT_COLOR
    );

    /**
     * Apply accent color to the DOM.
     * @param {string} hex
     */
    const applyAccentColor = hex => {
        requestAnimationFrame(() => applyAccentColorToDOM(hex ?? DEFAULT_ACCENT_COLOR));
    };

    /**
     * Persist the new accent color to the backend and apply it to the DOM.
     * @param {string} hex
     */
    const updateAccentColor = async hex => {
        try {
            await updateUISettings({ accent_color: hex });
            applyAccentColor(hex);
            useAlert(t('PROFILE_SETTINGS.FORM.INTERFACE_SECTION.ACCENT_COLOR.UPDATE_SUCCESS'));
        } catch (error) {
            useAlert(t('PROFILE_SETTINGS.FORM.INTERFACE_SECTION.ACCENT_COLOR.UPDATE_ERROR'));
        }
    };

    // Re-apply whenever the stored value changes (e.g. on initial load or external update)
    watch(
        () => uiSettings.value.accent_color,
        newColor => {
            applyAccentColor(newColor);
        },
        { immediate: true }
    );

    return {
        accentColorPresets: ACCENT_COLOR_PRESETS,
        currentAccentColor,
        applyAccentColor,
        updateAccentColor,
    };
};

export default useAccentColor;
