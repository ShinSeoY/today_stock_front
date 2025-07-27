import { createRouter, createWebHistory } from 'vue-router';
import Login from '../views/LoginPage.vue';
import StockAlert from '../views/StockAlertPage.vue';

const routes = [
    { path: '/', component: Login },
    { path: '/stock-alert', component: StockAlert },
];

const router = createRouter({
    history: createWebHistory(),
    routes,
});

export default router;
