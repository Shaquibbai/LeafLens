/** @type {import('tailwindcss').Config} */
export default {
  content: [
    "./index.html",
    "./src/**/*.{js,ts,jsx,tsx}",
  ],
  theme: {
    extend: {
      colors: {
        leaf: {
          50: '#f2f8f4',
          100: '#e1efe6',
          200: '#c5e0d0',
          300: '#9bc9b1',
          400: '#6cab8d',
          500: '#488f6f',
          600: '#357257',
          700: '#2c5b47',
          800: '#25493a',
          900: '#1b382d',
          950: '#0e1f19',
        },
        earth: {
          50: '#fbfaf8',
          100: '#f4f2ed',
          200: '#e7e2d9',
          300: '#d5ccc0',
          400: '#beafa0',
          500: '#a79483',
          600: '#957f70',
          700: '#7c685c',
          800: '#66564d',
          900: '#554841',
        },
      },
    },
  },
  plugins: [],
}
