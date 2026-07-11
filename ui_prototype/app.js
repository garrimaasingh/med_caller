document.addEventListener('DOMContentLoaded', () => {
  const navBtns = document.querySelectorAll('.nav-btn');
  const screens = document.querySelectorAll('.screen');
  const bottomNavItems = document.querySelectorAll('.nav-item');
  const pillTabs = document.querySelectorAll('.pill');
  const lineTabs = document.querySelectorAll('.tab');

  // Handle sidebar navigation
  navBtns.forEach(btn => {
    btn.addEventListener('click', () => {
      // Remove active class from all buttons and screens
      navBtns.forEach(b => b.classList.remove('active'));
      screens.forEach(s => s.classList.remove('active'));

      // Add active class to clicked button and target screen
      btn.classList.add('active');
      const targetId = btn.getAttribute('data-target');
      const targetScreen = document.getElementById(targetId);
      if(targetScreen) {
        targetScreen.classList.add('active');
      }
    });
  });

  // Handle bottom nav visual interaction
  bottomNavItems.forEach(item => {
    item.addEventListener('click', () => {
      // Find parent bottom-nav to scope the active class correctly
      const parentNav = item.closest('.bottom-nav');
      if (parentNav) {
        const items = parentNav.querySelectorAll('.nav-item');
        items.forEach(i => i.classList.remove('active'));
        item.classList.add('active');
      }
    });
  });

  // Handle pill tabs
  pillTabs.forEach(pill => {
    pill.addEventListener('click', () => {
      const parentTabs = pill.closest('.pill-tabs');
      if (parentTabs) {
        const pills = parentTabs.querySelectorAll('.pill');
        pills.forEach(p => p.classList.remove('active'));
        pill.classList.add('active');
      }
    });
  });

  // Handle line tabs
  lineTabs.forEach(tab => {
    tab.addEventListener('click', () => {
      const parentTabs = tab.closest('.line-tabs');
      if (parentTabs) {
        const tabs = parentTabs.querySelectorAll('.tab');
        tabs.forEach(t => t.classList.remove('active'));
        tab.classList.add('active');
      }
    });
  });

  // Flow simulation for Incoming Call (Unknown) -> Add Patient -> Success
  const unknownAddBtn = document.querySelector('#incoming-call-unknown .action-btn-group .accept');
  if (unknownAddBtn) {
    unknownAddBtn.addEventListener('click', () => {
      document.querySelector('.nav-btn[data-target="patient-added"]').click();
    });
  }

  // Flow simulation for Patient Added -> Profile
  const openProfileBtn = document.querySelector('#patient-added .btn-green-solid');
  if (openProfileBtn) {
    openProfileBtn.addEventListener('click', () => {
      document.querySelector('.nav-btn[data-target="patient-profile"]').click();
    });
  }

});
