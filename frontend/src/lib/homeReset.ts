// 홈 페이지 goHome 함수를 전역으로 공유 (Navbar 로고 클릭 시 상태 초기화)
let resetFn: (() => void) | null = null;

export function registerHomeReset(fn: () => void) {
	resetFn = fn;
}

export function unregisterHomeReset() {
	resetFn = null;
}

export function triggerHomeReset() {
	resetFn?.();
}
