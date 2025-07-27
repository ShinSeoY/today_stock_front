<template>
    <div class="page-container">
        <form class="alert-form" @submit.prevent="submitForm">
            <h2>📈 알림 신청</h2>

            <div class="form-group">
                <label>종목코드</label>
                <input v-model="form.stockCode" placeholder="예: 005930" />
                <small>네이버 증권 → 종목코드 복사</small>
            </div>

            <div class="form-group">
                <label>알림받을 이메일</label>
                <input v-model="form.email" placeholder="email@example.com" />
            </div>

            <div class="form-group">
                <label>설정값</label>
                <input v-model="form.threshold" placeholder="예: 80000" />
            </div>

            <div class="form-group">
                <label>조건</label>
                <select v-model="form.condition">
                    <option value="이상">이상</option>
                    <option value="이하">이하</option>
                </select>
            </div>

            <div class="form-group">
                <label>알림 반복 여부</label>
                <div class="toggle-buttons">
                    <button type="button" :class="form.repeat ? 'selected' : ''" @click="form.repeat = true">
                        계속 알림
                    </button>
                    <button type="button" :class="!form.repeat ? 'selected' : ''" @click="form.repeat = false">
                        일회성 알림
                    </button>
                </div>
            </div>

            <button type="submit" class="submit-button">알림 신청</button>

            <h3 class="alert-list-title">내 알림 리스트</h3>
        </form>
    </div>
</template>

<script setup>
import { ref } from 'vue';

const form = ref({
    stockCode: '',
    email: '',
    threshold: '',
    condition: '이상',
    repeat: true,
});

const submitForm = () => {
    console.log('폼 제출:', form.value);
};
</script>

<style scoped>
.page-container {
    display: flex;
    justify-content: center;
    padding: 2rem;
}

.alert-form {
    width: 100%;
    max-width: 480px;
    background: #fff;
    padding: 24px;
    border-radius: 12px;
    box-shadow: 0 2px 10px rgba(0, 0, 0, 0.05);
}

h2 {
    margin-bottom: 20px;
}

.form-group {
    margin-bottom: 16px;
    display: flex;
    flex-direction: column;
}

input,
select {
    padding: 10px;
    font-size: 15px;
    border: 1px solid #ccc;
    border-radius: 6px;
    margin-top: 6px;
}

small {
    font-size: 12px;
    color: #777;
    margin-top: 4px;
}

.toggle-buttons {
    display: flex;
    gap: 10px;
    margin-top: 8px;
}

.toggle-buttons button {
    flex: 1;
    padding: 10px;
    border: 1px solid #ccc;
    border-radius: 6px;
    background-color: #f5f5f5;
    color: #333;
    cursor: pointer;
    font-weight: 500;
    transition: all 0.2s ease;
}

.toggle-buttons button.selected {
    background-color: #2563eb;
    color: white;
    border: 1px solid #2563eb;
}

.submit-button {
    width: 100%;
    padding: 12px;
    font-size: 16px;
    background-color: #2563eb;
    color: white;
    border: none;
    border-radius: 6px;
    cursor: pointer;
    margin-top: 8px;
}

.alert-list-title {
    margin-top: 32px;
    font-weight: bold;
}
</style>
