// 결과 페이지는 navigation state로 recipe 데이터를 전달받음
// 직접 URL 접근 시 홈으로 리다이렉트 (클라이언트 전용 렌더링)
export const ssr = false;

export function load() {
	return {};
}
