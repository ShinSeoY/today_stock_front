<template>
    <div class="form-container">
        <h2>📈 주식 알림 신청</h2>

        <label>종목코드</label>
        <input v-model="symbol" type="text" placeholder="예: 005930" />
        <p class="helper-text">네이버 증권 접속 → 알림받고자 하는 종목코드 입력</p>

        <label>이메일</label>
        <input v-model="email" type="email" placeholder="example@example.com" />

        <label>알림받을 설정 값</label>
        <input v-model.number="targetPrice" type="number" placeholder="예: 80000" />

        <label>기준</label>
        <select v-model="condition">
            <option value="above">이상</option>
            <option value="below">이하</option>
        </select>

        <button @click="submitAlert">알림 신청</button>

        <div class="divider"></div>

        <h3>📋 내 알림 리스트</h3>
        <div v-if="alerts.length === 0">등록된 알림이 없습니다.</div>
        <ul>
            <li v-for="alert in alerts" :key="alert.id">
                {{ alert.symbol }} | {{ alert.email }} | {{ alert.targetPrice }}원
                {{ alert.condition === 'above' ? '이상' : '이하' }}
            </li>
        </ul>
    </div>
</template>

<script>
export default {
    data() {
        return {
            symbol: '',
            email: '',
            targetPrice: '',
            condition: 'above',
            alerts: [],
        };
    },
    methods: {
        validate() {
            if (!this.symbol || !/^\d+$/.test(this.symbol)) {
                alert('종목코드는 숫자만 입력하세요.');
                return false;
            }
            if (!this.email.includes('@')) {
                alert('올바른 이메일 형식을 입력하세요.');
                return false;
            }
            if (!this.targetPrice || isNaN(this.targetPrice) || this.targetPrice <= 0) {
                alert('유효한 가격을 입력하세요.');
                return false;
            }
            return true;
        },
        async submitAlert() {
            if (!this.validate()) return;

            try {
                // 예시용 API 호출 (실제 주소로 교체 필요)
                await fetch('https://your-api.com/alerts', {
                    method: 'POST',
                    headers: {
                        'Content-Type': 'application/json',
                    },
                    body: JSON.stringify({
                        symbol: this.symbol,
                        email: this.email,
                        targetPrice: this.targetPrice,
                        condition: this.condition,
                    }),
                });

                alert('알림이 등록되었습니다.');
                this.symbol = '';
                this.email = '';
                this.targetPrice = '';
                this.condition = 'above';

                this.loadAlerts();
            } catch (error) {
                alert('등록 중 오류가 발생했습니다.');
                console.error(error);
            }
        },
        async loadAlerts() {
            try {
                const response = await fetch('https://your-api.com/alerts'); // 실제 API 주소로 교체
                const data = await response.json();
                this.alerts = data;
            } catch (error) {
                console.error('알림 목록 불러오기 실패:', error);
            }
        },
    },
    mounted() {
        this.loadAlerts();
    },
};
</script>

<style scoped>
.form-container {
    max-width: 420px;
    margin: auto;
    padding: 20px;
    background: white;
    color: #333;
    font-family: sans-serif;
}
h2,
h3 {
    color: #005bcc;
}
input,
select,
button {
    display: block;
    width: 100%;
    margin-bottom: 15px;
    padding: 10px;
    font-size: 16px;
}
.helper-text {
    font-size: 12px;
    color: #666;
    margin-top: -10px;
    margin-bottom: 15px;
}
button {
    background-color: #005bcc;
    color: white;
    border: none;
    border-radius: 6px;
}
button:hover {
    background-color: #0043a9;
}
.divider {
    border-top: 1px solid #ccc;
    margin: 30px 0;
}
ul {
    list-style: none;
    padding: 0;
}
li {
    margin-bottom: 10px;
    font-size: 14px;
    line-height: 1.5;
}
</style>
