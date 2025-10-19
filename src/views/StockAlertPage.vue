<template>
    <div class="page-container">
        <form class="alert-form" @submit.prevent="submitForm">
            <h2>📈 알림 신청</h2>

            <!-- 종목 검색 -->
            <div class="form-group" ref="searchWrap">
                <label>종목검색</label>

                <input
                    v-model="searchQuery"
                    placeholder="종목명 또는 코드로 검색 (예: 삼성 또는 005930)"
                    autocomplete="off"
                    @focus="showSuggestions = true"
                    @keydown="onKeydown"
                />

                <small>검색어 입력 시 자동으로 결과가 나타납니다.</small>

                <div v-if="showSuggestions" class="suggestions">
                    <div v-if="isSearching && suggestions.length === 0" class="suggestions-empty">검색 중…</div>

                    <template v-else>
                        <div v-if="suggestions.length === 0 && searchQuery.trim()" class="suggestions-empty">
                            검색 결과가 없습니다.
                        </div>

                        <ul
                            v-else
                            class="suggestions-list"
                            role="listbox"
                            ref="suggestionsListRef"
                            @scroll="onSuggestionsScroll"
                        >
                            <li
                                v-for="(item, idx) in suggestions"
                                :key="item.code + (item.url || '') + idx"
                                :class="['suggestions-item', {active: idx === highlightedIndex}]"
                                role="option"
                                @mousedown.prevent="selectSuggestion(item)"
                                @mouseover="highlightedIndex = idx"
                            >
                                <div class="item-primary">
                                    <span class="item-name" v-html="highlightMatch(item.name)"></span>
                                    <span class="item-code">{{ item.code }}</span>
                                </div>
                                <div class="item-secondary">
                                    <span class="item-url">{{ item.url }}</span>
                                </div>
                            </li>

                            <!-- ✅ 로딩/끝 표시 -->
                            <li v-if="isLoadingMore" class="suggestions-empty">더 불러오는 중…</li>
                            <li v-else-if="!hasMore" class="suggestions-empty">검색 결과 끝</li>
                        </ul>
                    </template>
                </div>
            </div>

            <!-- 이메일 -->
            <div class="form-group">
                <label>알림받을 이메일</label>
                <input
                    v-model="form.email"
                    placeholder="email@example.com"
                    type="email"
                    inputmode="email"
                    autocomplete="email"
                    ref="emailInput"
                />
            </div>

            <!-- 지정가 -->
            <div class="form-group">
                <label>지정가</label>
                <input
                    v-model="form.threshold"
                    placeholder="예: 80000"
                    ref="thresholdInput"
                    inputmode="numeric"
                    :readonly="isThresholdLocked"
                    @focus="onAttempt('threshold')"
                />
            </div>

            <!-- 등락률 -->
            <div class="form-group">
                <label>등락률</label>
                <input
                    v-model="form.percent"
                    placeholder="예: 5%"
                    ref="percentInput"
                    :readonly="isPercentLocked"
                    @focus="onAttempt('percent')"
                />
            </div>

            <div class="form-group">
                <label>조건</label>
                <select v-model="form.condition">
                    <option value="GTE">이상</option>
                    <option value="LTE">이하</option>
                </select>
            </div>

            <!-- ▼ 템플릿의 버튼 교체 -->
            <button type="submit" class="submit-button" :disabled="isSubmitting">
                {{ isSubmitting ? '처리 중…' : '알림 신청' }}
            </button>

            <h3 class="alert-list-title">내 알림 리스트</h3>
            <div class="alarm-list">
                <div v-if="alarmsLoading" class="alarm-empty">불러오는 중…</div>
                <div v-else-if="alarmsError" class="alarm-empty">{{ alarmsError }}</div>
                <div v-else-if="alarms.length === 0" class="alarm-empty">등록된 알림이 없습니다.</div>

                <ul v-else class="alarm-items">
                    <li
                        v-for="a in alarms"
                        :key="a.code + String(a.date)"
                        class="alarm-card"
                        :class="{disabled: a.enable === false}"
                    >
                        <div class="a-left">
                            <div class="title-row">
                                <span class="name">{{ a.name }}</span>
                                <span class="code">· {{ a.code }}</span>
                            </div>

                            <div class="meta-row">
                                <span class="chip" :class="a.condition === 'GTE' ? 'chip-up' : 'chip-down'">
                                    {{ conditionKorean(a.condition) }}
                                </span>

                                <span class="dot">•</span>
                                <span class="price">{{ formatPrice(a.price) }} {{ a.currencyCode || 'KRW' }}</span>
                            </div>
                        </div>

                        <div class="a-right">
                            <!-- 상태 배지: 비활성일 때만 노출 -->
                            <span v-if="a.enable === false" class="status-badge off">비활성화됨</span>

                            <!-- 비활성 카드: 활성화 버튼만 -->
                            <div v-if="a.enable === false" class="btn-row">
                                <button
                                    type="button"
                                    class="activate-button"
                                    @click="activateAlarm(a)"
                                    :disabled="isDeleting(a.code) || isDisabling(a.code)"
                                    aria-label="알림 활성화"
                                    title="알림 활성화"
                                >
                                    {{ isDeleting(a.code) || isDisabling(a.code) ? '처리 중…' : '활성화' }}
                                </button>
                            </div>

                            <!-- 활성 카드: 비활성화/삭제 나란히 -->
                            <div v-else class="btn-row">
                                <button
                                    type="button"
                                    class="disable-button"
                                    @click="confirmDisable(a.code)"
                                    :disabled="isDeleting(a.code) || isDisabling(a.code)"
                                    aria-label="알림 비활성화"
                                    title="알림 비활성화"
                                >
                                    {{ isDisabling(a.code) ? '비활성화 중…' : '비활성화' }}
                                </button>

                                <button
                                    type="button"
                                    class="delete-button"
                                    @click="confirmDelete(a.code)"
                                    :disabled="isDeleting(a.code) || isDisabling(a.code)"
                                    aria-label="알림 삭제"
                                    title="알림 삭제"
                                >
                                    {{ isDeleting(a.code) ? '삭제 중…' : '삭제' }}
                                </button>
                            </div>

                            <span class="date">{{ formatDate(a.date) }}</span>
                            <span class="email">{{ a.email }}</span>
                        </div>
                    </li>
                </ul>

                <button type="button" class="refresh-button" @click="loadAlarms" :disabled="alarmsLoading">
                    {{ alarmsLoading ? '불러오는 중…' : '새로고침' }}
                </button>
            </div>
        </form>
    </div>
</template>

<script setup>
import {ref, watch, onMounted, onBeforeUnmount, nextTick, computed, reactive} from 'vue';

const selectedStock = ref(null);
const isSubmitting = ref(false);
const thresholdInput = ref(null);
const percentInput = ref(null);
const searchWrap = ref(null);
const emailInput = ref(null);
const form = ref({
    stockCode: '',
    email: '',
    threshold: '',
    percent: '',
    condition: 'GTE',
    repeat: true,
});

/** === 검색/페이지 상태 === **/
const searchQuery = ref('');
const suggestions = ref([]);
const isSearching = ref(false);
const showSuggestions = ref(false);
const highlightedIndex = ref(-1);
const suggestionsListRef = ref(null);

let debounceTimer = null;

// ✅ 페이지네이션용 상태
const PAGE_SIZE = 20; // 백엔드 페이지 크기(바뀌면 맞춰 수정)
const currentPage = ref(1);
const hasMore = ref(true);
const isLoadingMore = ref(false);
let lastKeyword = ''; // 같은 키워드로 추가 로드할 때 사용
let inFlight = false; // 중복 호출 방지

// 서로 배타 잠금 플래그
const isThresholdLocked = computed(() => !!form.value.percent?.toString().trim());
const isPercentLocked = computed(() => !!form.value.threshold?.toString().trim());

const isValidEmail = (v) => {
    const s = String(v || '').trim();
    if (!s) return false;
    return /^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$/.test(s);
};

/** === 공통 API 래퍼 === **/
const RAW_API_BASE = import.meta.env?.VITE_API_BASE_URL || '/api';

// '/api' 같은 상대 경로면 현재 오리진을 붙여 절대 URL로 변환
const BASE = RAW_API_BASE.endsWith('/') ? RAW_API_BASE : RAW_API_BASE + '/';
const API_BASE = new URL(BASE, window.location.origin);

const api = (path, options = {}) => {
    const clean = path.replace(/^\/+/, '');
    const url = new URL(clean, API_BASE).toString();
    return fetch(url, {credentials: 'include', ...options});
};

const alarms = ref([]);
const alarmsLoading = ref(false);
const alarmsError = ref('');

// 조건 한글 변환 (ConditionType: GTE/LTE 가정)
const conditionKorean = (c) => (String(c) === 'GTE' ? '이상' : '이하');

// 날짜 포맷 (LocalDateTime 문자열 대응)
const pad = (n) => (n < 10 ? '0' + n : '' + n);
const formatDate = (dt) => {
    if (!dt) return '';
    // 백엔드가 "2025-08-09T12:34:56" 같은 ISO 문자열을 보낸다고 가정
    const d = new Date(dt);
    if (isNaN(d.getTime())) return String(dt); // 혹시 파싱 실패하면 원문 표시
    return `${d.getFullYear()}.${pad(d.getMonth() + 1)}.${pad(d.getDate())} ${pad(d.getHours())}:${pad(
        d.getMinutes()
    )}`;
};

/** === 지정가 등락률 배타 잠금 플래그 === **/
const onAttempt = (field) => {
    if (field === 'threshold' && isThresholdLocked.value) {
        alert('지정가와 등락률은 동시에 입력할 수 없어요.\n등락률을 지우고 지정가를 입력하거나, 그대로 진행하세요.');
        percentInput.value?.focus?.();
    }
    if (field === 'percent' && isPercentLocked.value) {
        alert('지정가와 등락률은 동시에 입력할 수 없어요.\n지정가를 지우고 등락률을 입력하거나, 그대로 진행하세요.');
        thresholdInput.value?.focus?.();
    }
};

/** === 외부 클릭 시 닫기 === **/
const onClickOutside = (e) => {
    if (searchWrap.value && !searchWrap.value.contains(e.target)) {
        showSuggestions.value = false;
        highlightedIndex.value = -1;
    }
};
onMounted(() => {
    document.addEventListener('click', onClickOutside);
    loadAlarms(); // ✅ 초기 진입 시 불러오기
});
onBeforeUnmount(() => document.removeEventListener('click', onClickOutside));

/** === 유틸 === **/
const formatPrice = (n) => {
    if (n === null || n === undefined || isNaN(n)) return '';
    return `${Math.round(Number(n)).toLocaleString('ko-KR')}`;
};
const escapeRE = (s) => s.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
const highlightMatch = (text) => {
    const q = searchQuery.value.trim();
    if (!q) return text;
    try {
        const re = new RegExp(escapeRE(q), 'gi');
        return text.replace(re, (m) => `<mark>${m}</mark>`);
    } catch {
        return text;
    }
};

const toNumber = (v) => {
    if (v === null || v === undefined) return null;
    const n = parseFloat(
        String(v)
            .replace(/,/g, '')
            .replace(/[^\d.-]/g, '')
    );
    return Number.isFinite(n) ? n : null;
};
const parsePercent = (v) => {
    const n = toNumber(v);
    return n === null ? null : n; // "5"나 "5%" -> 5.0으로 취급
};

/** === 검색 입력 감지(디바운스) === **/
watch(
    () => searchQuery.value,
    (q) => {
        showSuggestions.value = true;
        highlightedIndex.value = -1;
        if (debounceTimer) clearTimeout(debounceTimer);
        if (!q.trim()) {
            suggestions.value = [];
            isSearching.value = false;
            hasMore.value = true;
            currentPage.value = 1;
            return;
        }
        debounceTimer = setTimeout(() => doSearch(q.trim(), /* reset */ true), 350);
    }
);

/** === 스크롤 핸들러: 바닥 근처면 다음 페이지 로드 === **/
const onSuggestionsScroll = (e) => {
    if (!hasMore.value || isLoadingMore.value) return;
    const el = e.target;
    // 바닥에서 48px 남았을 때 추가 로드
    if (el.scrollTop + el.clientHeight >= el.scrollHeight - 48) {
        loadMore();
    }
};

/** === API: 페이지 단위 검색 === **/
const fetchSearchPage = async (keyword, page) => {
    const res = await api('v1/user/stock/search', {
        method: 'POST',
        headers: {'Content-Type': 'application/json'},
        body: JSON.stringify({keyword, page}),
    });
    const json = await res.json();
    const list = json?.data ?? json?.result ?? [];
    return Array.isArray(list) ? list : [];
};

/** === 첫 페이지 or 키워드 변경 검색 === **/
const doSearch = async (keyword, reset = false) => {
    if (inFlight) return;
    inFlight = true;
    try {
        if (reset || keyword !== lastKeyword) {
            isSearching.value = true;
            suggestions.value = [];
            currentPage.value = 1;
            hasMore.value = true;
            lastKeyword = keyword;
        }

        const list = await fetchSearchPage(keyword, currentPage.value);
        suggestions.value = list;
        // ✅ 더 불러올 수 있는지 추정(백엔드가 total을 주면 그걸로 판단)
        hasMore.value = list.length >= PAGE_SIZE;
    } catch (e) {
        console.error(e);
        hasMore.value = false;
    } finally {
        isSearching.value = false;
        inFlight = false;
    }
};

/** === 다음 페이지 로드 === **/
const loadMore = async () => {
    if (!hasMore.value || isLoadingMore.value || !lastKeyword) return;
    isLoadingMore.value = true;
    try {
        const nextPage = currentPage.value + 1;
        const list = await fetchSearchPage(lastKeyword, nextPage);
        if (list.length > 0) {
            suggestions.value = suggestions.value.concat(list);
            currentPage.value = nextPage;
        }
        // ✅ 더 없음 판단
        if (list.length < PAGE_SIZE) hasMore.value = false;
    } catch (e) {
        console.error(e);
        hasMore.value = false;
    } finally {
        isLoadingMore.value = false;
    }
};

/** === 키보드 내비게이션 === **/
const onKeydown = (e) => {
    if (!showSuggestions.value || suggestions.value.length === 0) return;
    if (e.key === 'ArrowDown') {
        e.preventDefault();
        highlightedIndex.value = (highlightedIndex.value + 1) % suggestions.value.length;
    } else if (e.key === 'ArrowUp') {
        e.preventDefault();
        highlightedIndex.value = (highlightedIndex.value - 1 + suggestions.value.length) % suggestions.value.length;
    } else if (e.key === 'Enter') {
        if (highlightedIndex.value >= 0) {
            e.preventDefault();
            selectSuggestion(suggestions.value[highlightedIndex.value]);
        }
    } else if (e.key === 'Escape') {
        showSuggestions.value = false;
    }
};

/** === 상세 조회 === **/
const fetchDetail = async (item) => {
    const payload = item?.url ? {url: item.url} : {code: item.code};
    const res = await api('v1/user/stock/detail', {
        method: 'POST',
        headers: {'Content-Type': 'application/json'},
        body: JSON.stringify(payload),
    });
    const json = await res.json();
    return json?.data ?? json?.result ?? null;
};

const toPlainInt = (v) => {
    if (v === null || v === undefined) return null;
    if (typeof v === 'number') return Math.round(v);
    const n = Number(String(v).replace(/[^\d.]/g, ''));
    return Number.isFinite(n) ? Math.round(n) : null;
};

const selectSuggestion = async (item) => {
    try {
        const detail = await fetchDetail(item);
        if (!detail) return;

        form.value.stockCode = detail.code;
        searchQuery.value = `${detail.name} (${detail.code}) · ${formatPrice(detail.price)} ${
            detail.currencyCode || 'KRW'
        }`;
        selectedStock.value = {
            code: detail.code,
            url: item.url || '',
            price: Number(detail.price),
            name: detail.name,
            currencyCode: detail.currencyCode || 'KRW',
        };

        // 지정가 자동 채우기 유지
        const priceInt = toPlainInt(detail.price);
        form.value.threshold = priceInt !== null ? String(priceInt) : '';

        showSuggestions.value = false;
        highlightedIndex.value = -1;

        await nextTick();
        thresholdInput.value?.focus?.();
        thresholdInput.value?.select?.();
    } catch (e) {
        console.error(e);
    }
};

const submitForm = async () => {
    if (!selectedStock.value?.code) {
        alert('종목을 먼저 선택해주세요.');
        return;
    }

    if (!form.value.email?.trim()) {
        alert('알림받을 이메일을 입력해주세요.');
        emailInput.value?.focus?.();
        return;
    }

    if (!isValidEmail(form.value.email)) {
        alert('이메일 형식이 올바르지 않습니다. 예: name@example.com');
        emailInput.value?.focus?.();
        emailInput.value?.select?.();
        return;
    }

    const currentPrice = toNumber(selectedStock.value.price);
    const requestPrice = toNumber(form.value.threshold);
    const percent = parsePercent(form.value.percent);

    if (requestPrice === null && percent === null) {
        alert('지정가 또는 등락률 중 하나 이상을 입력해주세요.');
        return;
    }

    const payload = {
        stock: {
            code: selectedStock.value.code,
            url: selectedStock.value.url,
            name: selectedStock.value.name,
            currencyCode: selectedStock.value.currencyCode,
        },
        requestEmail: form.value.email.trim(),
        currentPrice: currentPrice ?? 0,
        requestPrice: requestPrice,
        percent: percent,
        condition: form.value.condition,
    };

    try {
        isSubmitting.value = true;
        const res = await api('v1/user/alarm', {
            method: 'POST',
            headers: {'Content-Type': 'application/json'},
            body: JSON.stringify(payload),
        });
        const json = await res.json().catch(() => ({}));
        if (!res.ok) throw new Error(json?.message || '알림 신청에 실패했습니다.');

        alert('알림이 등록되었어요!');
        console.log('alarm response:', json);
        searchQuery.value = '';
        form.value.email = '';
        form.value.percent = '';
        form.value.threshold = '';

        await loadAlarms();
    } catch (e) {
        console.error(e);
        alert(e.message || '알림 신청 중 오류가 발생했습니다.');
    } finally {
        isSubmitting.value = false;
    }
};

// 알림 목록 로드
const loadAlarms = async () => {
    try {
        alarmsLoading.value = true;
        alarmsError.value = '';
        const res = await api('v1/user/alarm', {
            method: 'GET',
            headers: {'Content-Type': 'application/json'},
        });
        const json = await res.json().catch(() => ({}));
        if (!res.ok) throw new Error(json?.message || '알림 목록을 불러오지 못했습니다.');
        const list = json?.data ?? json?.result ?? [];
        alarms.value = Array.isArray(list) ? list : [];
    } catch (e) {
        console.error(e);
        alarmsError.value = e.message || '알림 목록 로드 중 오류가 발생했습니다.';
    } finally {
        alarmsLoading.value = false;
    }
};

// 활성화: 비활성 알림을 /save 로 재저장
const activateAlarm = async (a) => {
    try {
        deleting[a.code] = true;

        const payload = {
            stock: {
                code: a.code,
                url: a.url || '',
                name: a.name,
                currencyCode: a.currencyCode || 'KRW',
            },
            requestEmail: String(a.email || '').trim(),
            calcPrice: Number(a.price),
            condition: a.condition || 'GTE',
        };

        const res = await api('v1/user/alarm', {
            method: 'POST',
            headers: {'Content-Type': 'application/json'},
            body: JSON.stringify(payload),
        });
        const json = await res.json().catch(() => ({}));
        if (!res.ok) throw new Error(json?.message || '알림 활성화에 실패했습니다.');

        alert('알림이 활성화되었어요!');
        await loadAlarms();
    } catch (e) {
        console.error(e);
        alert(e.message || '활성화 중 오류가 발생했습니다.');
    } finally {
        deleting[a.code] = false;
    }
};

// ===== 삭제/비활성화 상태 관리 =====
const deleting = reactive({}); // code -> boolean (기존)
const disabling = reactive({}); // code -> boolean (신규)

const isDeleting = (code) => !!deleting[code];
const isDisabling = (code) => !!disabling[code];

// 비활성화 확인 다이얼로그
const confirmDisable = async (code) => {
    if (!code) return;
    if (!confirm('이 알림을 비활성화할까요?')) return;
    await disableAlarm(code);
};

// /disable 호출
const disableAlarm = async (code) => {
    try {
        disabling[code] = true;

        const url = `v1/user/alarm/${encodeURIComponent(code)}`;
        const res = await api(url, {
            method: 'PUT',
            headers: {'Content-Type': 'application/json'},
        });
        const json = await res.json().catch(() => ({}));
        if (!res.ok) throw new Error(json?.message || '알림 비활성화에 실패했습니다.');

        alert('알림이 비활성화되었어요.');
        await loadAlarms();
    } catch (e) {
        console.error(e);
        alert(e.message || '비활성화 중 오류가 발생했습니다.');
    } finally {
        disabling[code] = false;
    }
};

const confirmDelete = async (code) => {
    if (!code) return;
    if (!confirm('이 알림을 삭제할까요?')) return;
    await deleteAlarm(code);
};

const deleteAlarm = async (code) => {
    try {
        deleting[code] = true;
        const url = `v1/user/alarm/${encodeURIComponent(code)}`;
        const res = await api(url, {
            method: 'DELETE',
            headers: {Accept: 'application/json'},
        });
        const json = await res.json().catch(() => ({}));
        if (!res.ok) throw new Error(json?.message || '알림 삭제에 실패했습니다.');
        alarms.value = alarms.value.filter((a) => a.code !== code);
    } catch (e) {
        console.error(e);
        alert(e.message || '삭제 중 오류가 발생했습니다.');
    } finally {
        deleting[code] = false;
    }
};
</script>

<style scoped>
/* ===== 레이아웃 ===== */
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

/* ===== 폼 공통 ===== */
.form-group {
    margin-bottom: 16px;
    display: flex;
    flex-direction: column;
    position: relative; /* 드롭다운 포지셔닝 */
}

input,
select {
    padding: 10px;
    font-size: 15px;
    border: 1px solid #d1d5db;
    border-radius: 8px;
    margin-top: 6px;
    outline: none;
    transition:
        border-color 0.15s ease,
        box-shadow 0.15s ease;
}
input:focus,
select:focus {
    border-color: #2563eb;
    box-shadow: 0 0 0 3px rgba(37, 99, 235, 0.15);
}

small {
    font-size: 12px;
    color: #6b7280;
    margin-top: 4px;
}

/* ===== 자동완성 드롭다운 ===== */
.suggestions {
    position: absolute;
    top: calc(100% + 6px);
    left: 0;
    right: 0;
    background: #fff;
    border: 1px solid #e5e7eb;
    border-radius: 10px;
    box-shadow: 0 8px 24px rgba(0, 0, 0, 0.08);
    z-index: 20;
    overflow: hidden;
    max-height: 320px;
    display: flex;
    flex-direction: column;
}
.suggestions-empty {
    padding: 14px 12px;
    color: #6b7280;
    font-size: 14px;
}
.suggestions-list {
    list-style: none;
    margin: 0;
    padding: 6px 0;
    overflow-y: auto;
    max-height: 320px;
}
.suggestions-item {
    padding: 10px 12px;
    display: grid;
    grid-template-columns: 1fr auto;
    gap: 6px 12px;
    cursor: pointer;
}
.suggestions-item:hover,
.suggestions-item.active {
    background: #f3f4f6;
}
.item-primary {
    display: flex;
    gap: 8px;
    align-items: baseline;
}
.item-name {
    font-weight: 600;
}
.item-code {
    font-size: 12px;
    color: #6b7280;
}
.item-secondary {
    font-size: 11px;
    color: #9ca3af;
    text-align: right;
}

mark {
    background: #fff2ac;
    padding: 0 2px;
    border-radius: 3px;
}

/* ===== 제출 버튼 ===== */
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

/* ===== 리스트 컨테이너 ===== */
.alert-list-title {
    margin-top: 32px;
    font-weight: bold;
}

.alarm-list {
    margin-top: 12px;
}

.alarm-empty {
    padding: 12px;
    color: #6b7280;
    font-size: 14px;
    text-align: center;
    background: #f9fafb;
    border: 1px solid #eef2f7;
    border-radius: 8px;
}

/* ===== 알림 카드 ===== */
.alarm-items {
    list-style: none;
    padding: 0;
    margin: 0;
    display: grid;
    gap: 10px;
}

.alarm-card {
    display: grid;
    grid-template-columns: 1fr auto;
    gap: 6px 16px;
    padding: 14px;
    background: #fff;
    border: 1px solid #e5e7eb;
    border-radius: 12px;
    box-shadow: 0 2px 10px rgba(0, 0, 0, 0.05);
}
.alarm-card:hover {
    border-color: #c7d2fe; /* indigo-200 느낌 */
    box-shadow: 0 4px 14px rgba(37, 99, 235, 0.08);
}

/* 비활성 카드: 배경/테두리/텍스트를 회색톤으로 */
.alarm-card.disabled {
    background: #f9fafb; /* 옅은 회색 배경 */
    border: 1px solid #e5e7eb;
    color: #6b7280; /* 텍스트 전체 톤 다운 */
    opacity: 1; /* 기존의 흐림(opacity) 대신 확실한 색상톤 사용 */
    filter: none; /* grayscale 제거 */
}

/* 비활성 카드 안의 제목/코드/가격도 회색 계열 */
.alarm-card.disabled .name,
.alarm-card.disabled .code,
.alarm-card.disabled .price,
.alarm-card.disabled .date,
.alarm-card.disabled .email {
    color: #9ca3af; /* 더 옅은 회색 */
}

/* 비활성 카드 hover 시 효과 제거 (활성 카드와 구분) */
.alarm-card.disabled:hover {
    border-color: #e5e7eb;
    box-shadow: none;
}

/* ===== 좌측(제목/메타) ===== */
.title-row {
    display: flex;
    gap: 6px;
    align-items: baseline;
}
.name {
    font-weight: 700;
    font-size: 15px;
    color: #111827;
}
.code {
    font-size: 12px;
    color: #6b7280;
}

.meta-row {
    display: flex;
    align-items: center;
    gap: 8px;
    margin-top: 4px;
    font-size: 13px;
    color: #374151;
}
.dot {
    color: #9ca3af;
}
.price {
    font-weight: 600;
}

/* 조건 배지 */
.chip {
    font-size: 12px;
    padding: 2px 8px;
    border-radius: 9999px;
    border: 1px solid;
    font-weight: 600;
}
.chip-up {
    background: #eff6ff;
    color: #2563eb;
    border-color: #dbeafe;
}
.chip-down {
    background: #fef2f2;
    color: #dc2626;
    border-color: #fee2e2;
}

/* ===== 우측(버튼/정보) ===== */
.a-right {
    text-align: right;
    display: flex;
    flex-direction: column;
    align-items: flex-end;
    gap: 8px;
}

/* 상태 배지(우측 상단만 사용) */
.status-badge {
    font-size: 11px;
    padding: 2px 8px;
    border-radius: 9999px;
    border: 1px solid #e5e7eb;
}
.status-badge.off {
    background: #f3f4f6;
    color: #6b7280;
    border-color: #e5e7eb;
}

/* 버튼 가로 정렬 */
.btn-row {
    display: flex;
    gap: 6px;
}

/* 공용 버튼 크기 */
.btn-row button,
.delete-button,
.disable-button,
.activate-button {
    padding: 6px 10px;
    font-size: 12px;
    border-radius: 9999px;
    transition:
        border-color 0.15s ease,
        box-shadow 0.15s ease,
        background-color 0.15s ease;
}

/* 활성화 버튼 */
.activate-button {
    background: #2563eb;
    color: #ffffff;
    border: 1px solid #2563eb;
    cursor: pointer;
}
.activate-button:hover {
    background: #1d4ed8;
    border-color: #1d4ed8;
    box-shadow: 0 0 0 3px rgba(37, 99, 235, 0.15);
}
.activate-button:disabled {
    opacity: 0.6;
    cursor: default;
    box-shadow: none;
}

/* 비활성화 버튼 */
.disable-button {
    background: #fff7ed; /* orange-50 */
    color: #c2410c; /* orange-700 */
    border: 1px solid #fed7aa; /* orange-200 */
    cursor: pointer;
}
.disable-button:hover {
    background: #ffedd5; /* orange-100 */
    border-color: #fb923c; /* orange-400 */
    box-shadow: 0 0 0 3px rgba(251, 146, 60, 0.15);
}
.disable-button:disabled {
    opacity: 0.6;
    cursor: not-allowed;
    box-shadow: none;
}

/* 삭제 버튼 */
.delete-button {
    background: #ffffff;
    color: #b91c1c;
    border: 1px solid #fca5a5; /* light red */
    cursor: pointer;
}
.delete-button:hover {
    background: #fff5f5;
    border-color: #ef4444;
    box-shadow: 0 0 0 3px rgba(239, 68, 68, 0.12);
}
.delete-button:disabled {
    opacity: 0.45;
    cursor: not-allowed;
    box-shadow: none;
}

.date {
    font-size: 12px;
    color: #9ca3af;
}
.email {
    font-size: 12px;
    color: #6b7280;
}

/* ===== 새로고침 버튼 ===== */
.refresh-button {
    width: 100%;
    margin-top: 12px;
    padding: 10px 12px;
    font-size: 14px;
    background: #ffffff;
    color: #111827;
    border: 1px solid #d1d5db;
    border-radius: 8px;
    cursor: pointer;
    transition:
        border-color 0.15s ease,
        box-shadow 0.15s ease;
}
.refresh-button:hover {
    border-color: #2563eb;
    box-shadow: 0 0 0 3px rgba(37, 99, 235, 0.12);
}
.refresh-button:disabled {
    opacity: 0.6;
    cursor: default;
    box-shadow: none;
}
</style>
