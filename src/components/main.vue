<template>
    <div class="login-form">
        <h2>로그인</h2>
        <input type="text" v-model="username" placeholder="아이디 입력" />
        <input type="password" v-model="password" placeholder="비밀번호 입력" />
        <button @click="login">로그인</button>
    </div>
</template>

<script>
export default {
    name: 'LoginForm',
    data() {
        return {
            username: '',
            password: '',
        };
    },
    methods: {
        login() {
            alert(`아이디: ${this.username}\n비밀번호: ${this.password}`);
        },
    },
};
</script>

<style>
.login-form {
    display: flex;
    flex-direction: column;
    width: 300px;
    margin: 100px auto;
}
.login-form input,
.login-form button {
    margin-bottom: 10px;
    padding: 10px;
}
</style>
