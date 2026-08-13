import { defineCustomElements } from '@ionic/core/loader';
import { initTheme } from './lib/theme.js';
import { resolveLaunchScreen } from './lib/supabase-client.js';
import { registerScreen, showScreen } from './router.js';

import * as signin from './screens/signin.js';
import * as unlock from './screens/unlock.js';
import * as forgotPassword from './screens/forgot-password.js';
import * as dashboard from './screens/dashboard.js';
import * as documents from './screens/documents.js';
import * as documentDetail from './screens/document-detail.js';
import * as profile from './screens/profile.js';
import * as adminInsights from './screens/admin-insights.js';

defineCustomElements(window);

registerScreen('signin', signin.mount);
registerScreen('unlock', unlock.mount);
registerScreen('forgot-password', forgotPassword.mount);
registerScreen('dashboard', dashboard.mount);
registerScreen('documents', documents.mount);
registerScreen('document-detail', documentDetail.mount);
registerScreen('profile', profile.mount);
registerScreen('admin-insights', adminInsights.mount);

async function boot() {
  await initTheme();
  const launchScreen = await resolveLaunchScreen();
  showScreen(launchScreen);
}

boot();
