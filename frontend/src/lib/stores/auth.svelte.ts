import { supabase } from '$lib/supabase';
import type { User, Session } from '@supabase/supabase-js';

// 반응형 상태
let user = $state<User | null>(null);
let session = $state<Session | null>(null);
let loading = $state(true);
let modalOpen = $state(false);
let modalRedirect = $state<string | null>(null);

// 초기화: 앱 시작 시 1회 호출
export async function initAuth() {
	const { data } = await supabase.auth.getSession();
	session = data.session;
	user = data.session?.user ?? null;
	loading = false;

	// 세션 변경 리스너
	supabase.auth.onAuthStateChange((_event, newSession) => {
		session = newSession;
		user = newSession?.user ?? null;
	});
}

// Google 로그인
export async function signInWithGoogle(redirectTo?: string) {
	const callbackUrl = `${window.location.origin}/auth/callback${redirectTo ? `?redirect=${encodeURIComponent(redirectTo)}` : ''}`;
	await supabase.auth.signInWithOAuth({
		provider: 'google',
		options: { redirectTo: callbackUrl }
	});
}

// 로그아웃
export async function signOut() {
	await supabase.auth.signOut();
	user = null;
	session = null;
}

// 로그인 모달 제어
export function openLoginModal(redirect?: string) {
	modalRedirect = redirect ?? null;
	modalOpen = true;
}
export function closeLoginModal() { modalOpen = false; }

// 읽기 전용 접근자
export function getUser() { return user; }
export function getSession() { return session; }
export function isLoading() { return loading; }
export function isLoggedIn() { return !!user; }
export function isModalOpen() { return modalOpen; }
export function getModalRedirect() { return modalRedirect; }
