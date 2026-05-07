<template>
  <div class="app-root">
    <NuxtPage />
  </div>
</template>

<style>
@import url("https://fonts.googleapis.com/css2?family=DM+Sans:ital,opsz,wght@0,9..40,400;0,9..40,600;1,9..40,400&display=swap");

*,
*::before,
*::after {
  box-sizing: border-box;
}

html {
  font-family: "DM Sans", system-ui, sans-serif;
  line-height: 1.5;
  color: #0f172a;
  background: radial-gradient(1200px 600px at 10% -10%, #e0e7ff 0%, transparent 55%),
    radial-gradient(900px 500px at 100% 0%, #cffafe 0%, transparent 50%),
    #f8fafc;
  min-height: 100%;
}

body {
  margin: 0;
  min-height: 100vh;
}

.app-root {
  min-height: 100vh;
  display: flex;
  align-items: center;
  justify-content: center;
  padding: 1.5rem;
}
</style>
