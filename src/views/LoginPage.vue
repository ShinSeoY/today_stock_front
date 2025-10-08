<template>
    <div class="login-wrapper">
        <div class="login-box">
            <h1>📌 주식 알림 서비스</h1>
            <a :href="googleLoginUrl">
                <button class="login-button google">Google로 간편 로그인</button>
            </a>
            <a :href="kakaoLoginUrl">
                <button class="login-button kakao">카카오로 로그인</button>
            </a>
        </div>
    </div>
</template>

<script setup>
const API_BASE_URL = import.meta.env?.VITE_API_BASE_URL || '/api';
const googleLoginUrl = API_BASE_URL + '/oauth2/authorization/google';
const kakaoLoginUrl = API_BASE_URL + '/oauth2/authorization/kakao';
</script>

<style scoped>
.login-wrapper {
    display: flex;
    justify-content: center;
    align-items: center;
    height: 100vh;
    background-color: #f6f7fb;
}

.login-box {
    background: white;
    padding: 40px 30px;
    border-radius: 16px;
    box-shadow: 0 8px 30px rgba(0, 0, 0, 0.08);
    text-align: center;
    min-width: 320px;
}

h1 {
    margin-bottom: 30px;
    font-size: 24px;
    font-weight: bold;
    color: #333;
}

.login-button {
    display: block;
    width: 100%;
    padding: 12px 0;
    margin-top: 12px;
    font-size: 16px;
    border: none;
    border-radius: 8px;
    font-weight: 500;
    cursor: pointer;
    transition: background 0.2s ease;
}

.login-button.google {
    background-color: #4285f4;
    color: white;
}

.login-button.google:hover {
    background-color: #357ae8;
}

.login-button.kakao {
    background-color: #fee500;
    color: #3c1e1e;
}

.login-button.kakao:hover {
    background-color: #ffea00;
}
</style>
