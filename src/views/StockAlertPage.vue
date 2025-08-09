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

                <!-- 드롭다운 -->
                <div v-if="showSuggestions" class="suggestions">
                    <div v-if="isSearching && suggestions.length === 0" class="suggestions-empty">검색 중…</div>

                    <template v-else>
                        <div v-if="suggestions.length === 0 && searchQuery.trim()" class="suggestions-empty">
                            검색 결과가 없습니다.
                        </div>

                        <!-- ✅ 스크롤 이벤트 연결 -->
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
                                :class="['suggestions-item', { active: idx === highlightedIndex }]"
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

            <div class="form-group">
                <label>알림받을 이메일</label>
                <input v-model="form.email" placeholder="email@example.com" />
            </div>

            <div class="form-group">
                <label>지정가</label>
                <input v-model="form.threshold" placeholder="예: 80000" ref="thresholdInput" inputmode="numeric" />
            </div>

            <div class="form-group">
                <label>등락률</label>
                <input v-model="form.percent" placeholder="예: 5%" />
            </div>

            <div class="form-group">
                <label>조건</label>
                <select v-model="form.condition">
                    <option value="이상">이상</option>
                    <option value="이하">이하</option>
                </select>
            </div>

            <button type="submit" class="submit-button">알림 신청</button>

            <h3 class="alert-list-title">내 알림 리스트</h3>
        </form>
    </div>
</template>

<script setup>
import { ref, watch, onMounted, onBeforeUnmount, nextTick } from 'vue';

const form = ref({
    stockCode: '',
    email: '',
    threshold: '',
    percent: '',
    condition: '이상',
    repeat: true,
});

/** === 공통 API 래퍼 === **/
const API_BASE_URL = (import.meta.env?.VITE_API_BASE_URL || 'http://localhost:8080').replace(/\/?$/, '/');
const api = (path, options = {}) => {
    const url = new URL(path, API_BASE_URL).toString();
    return fetch(url, { credentials: 'include', ...options });
};

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

/** === 외부 클릭 시 닫기 === **/
const searchWrap = ref(null);
const onClickOutside = (e) => {
    if (searchWrap.value && !searchWrap.value.contains(e.target)) {
        showSuggestions.value = false;
        highlightedIndex.value = -1;
    }
};
onMounted(() => document.addEventListener('click', onClickOutside));
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
    const res = await api('/api/v1/user/stock/search', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ keyword, page }),
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
    const payload = item?.url ? { url: item.url } : { code: item.code };
    const res = await api('/api/v1/user/stock/detail', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(payload),
    });
    const json = await res.json();
    return json?.data ?? json?.result ?? null;
};

// (추가) 지정가 인풋 ref
const thresholdInput = ref(null);

// (추가) 문자열/숫자 price를 깔끔한 정수로 변환
const toPlainInt = (v) => {
    if (v === null || v === undefined) return null;
    if (typeof v === 'number') return Math.round(v);
    const n = Number(String(v).replace(/[^\d.]/g, ''));
    return Number.isFinite(n) ? Math.round(n) : null;
};

// 선택 시: 종목코드 + 표시 문자열 설정 + ✅ 지정가 자동 채우기
const selectSuggestion = async (item) => {
    try {
        const detail = await fetchDetail(item);
        if (!detail) return;

        form.value.stockCode = detail.code;
        searchQuery.value = `${detail.name} (${detail.code}) · ${formatPrice(detail.price)}`;

        // ✅ 지정가 채우기
        const priceInt = toPlainInt(detail.price);
        form.value.threshold = priceInt !== null ? String(priceInt) : '';

        showSuggestions.value = false;
        highlightedIndex.value = -1;

        // (선택) UX: 지정가 칸에 포커스 & 전체 선택
        await nextTick();
        thresholdInput.value?.focus?.();
        thresholdInput.value?.select?.();
    } catch (e) {
        console.error(e);
    }
};

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
    position: relative; /* 드롭다운 포지셔닝용 */
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

/* 드롭다운 */
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

.suggestions-list {
    list-style: none;
    margin: 0;
    padding: 6px 0;
    overflow-y: auto;
    max-height: 320px;
}

.suggestions-empty {
    padding: 12px;
    color: #6b7280;
    font-size: 14px;
    text-align: center;
}
</style>
