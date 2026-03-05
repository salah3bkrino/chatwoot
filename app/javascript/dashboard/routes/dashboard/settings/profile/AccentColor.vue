<script setup>
import { useAccentColor } from 'dashboard/composables/useAccentColor';

const { accentColorPresets, currentAccentColor, updateAccentColor } =
  useAccentColor();

const props = defineProps({
  label: {
    type: String,
    default: '',
  },
  description: {
    type: String,
    default: '',
  },
});
</script>

<template>
  <div class="flex gap-2 justify-between w-full items-start">
    <!-- Label + description -->
    <div>
      <label class="text-n-gray-12 font-medium leading-6 text-sm">
        {{ label }}
      </label>
      <p class="text-n-gray-11 text-sm">
        {{ description }}
      </p>
    </div>

    <!-- Color swatches -->
    <div class="flex flex-wrap gap-2 mt-1 max-w-[200px] justify-end">
      <button
        v-for="color in accentColorPresets"
        :key="color.id"
        :title="color.label"
        class="relative w-7 h-7 rounded-full border-2 transition-transform duration-150 hover:scale-110 focus:outline-none focus:ring-2 focus:ring-offset-2"
        :style="{
          backgroundColor: color.hex,
          borderColor:
            currentAccentColor === color.hex ? color.hex : 'transparent',
          boxShadow:
            currentAccentColor === color.hex
              ? `0 0 0 2px white, 0 0 0 4px ${color.hex}`
              : 'none',
        }"
        @click="updateAccentColor(color.hex)"
      >
        <!-- Checkmark for active color -->
        <span
          v-if="currentAccentColor === color.hex"
          class="absolute inset-0 flex items-center justify-center"
        >
          <svg
            width="12"
            height="12"
            viewBox="0 0 12 12"
            fill="none"
            xmlns="http://www.w3.org/2000/svg"
          >
            <path
              d="M2 6L5 9L10 3"
              stroke="white"
              stroke-width="1.8"
              stroke-linecap="round"
              stroke-linejoin="round"
            />
          </svg>
        </span>
      </button>
    </div>
  </div>
</template>
