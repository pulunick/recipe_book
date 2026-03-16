import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/api_service.dart';
import '../../core/theme.dart';

class MeokdangChatSheet extends ConsumerStatefulWidget {
  const MeokdangChatSheet({super.key});

  @override
  ConsumerState<MeokdangChatSheet> createState() => _MeokdangChatSheetState();
}

class _MeokdangChatSheetState extends ConsumerState<MeokdangChatSheet> {
  final List<_Msg> _messages = [];
  final _inputController = TextEditingController();
  final _scrollController = ScrollController();
  bool _isTyping = false;

  String? get _userName {
    final meta = Supabase.instance.client.auth.currentUser?.userMetadata;
    return meta?['full_name'] as String? ?? meta?['name'] as String?;
  }

  @override
  void initState() {
    super.initState();
    _messages.add(const _Msg(
      role: 'assistant',
      text: '안녕하세요! 저는 먹당이예요 🍳\n오늘 뭐 드셨어요? 맛있는 이야기 나눠요~',
    ));
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _send(String text) async {
    final msg = text.trim();
    if (msg.isEmpty || _isTyping) return;
    _inputController.clear();

    setState(() {
      _messages.add(_Msg(role: 'user', text: msg));
      _isTyping = true;
    });
    _scrollToBottom();

    try {
      final history = _messages
          .sublist(0, _messages.length - 1)
          .map((m) => {'role': m.role, 'content': m.text})
          .toList();

      final reply = await ref.read(apiServiceProvider).meokdangChat(
            msg,
            history,
            userName: _userName,
          );

      if (!mounted) return;
      setState(() {
        _messages.add(_Msg(role: 'assistant', text: reply));
        _isTyping = false;
      });
    } catch (e) {
      if (!mounted) return;
      final errText = e.toString().contains('429')
          ? '잠깐만요~ 너무 많이 물어보셨어요 😅 조금 후에 다시 말 걸어주세요!'
          : '앗, 잠깐 연결이 안 됐어요. 다시 시도해볼게요 🙏';
      setState(() {
        _messages.add(_Msg(role: 'assistant', text: errText));
        _isTyping = false;
      });
    }
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _clearHistory() {
    setState(() {
      _messages.clear();
      _messages.add(const _Msg(
        role: 'assistant',
        text: '대화를 초기화했어요! 또 무슨 이야기 해볼까요? 😊',
      ));
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: paperColor,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        children: [
          // 헤더
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 12, 0),
            child: Column(
              children: [
                Center(
                  child: Container(
                    width: 40, height: 4,
                    decoration: BoxDecoration(
                      color: lightLineColor,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Container(
                      width: 36, height: 36,
                      decoration: const BoxDecoration(color: primaryColor, shape: BoxShape.circle),
                      child: const Icon(Icons.restaurant, color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 10),
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('먹당이', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: darkColor)),
                        Text('AI 음식 친구', style: TextStyle(fontSize: 11, color: softBrownColor)),
                      ],
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: _clearHistory,
                      icon: const Icon(Icons.refresh, color: softBrownColor, size: 20),
                      tooltip: '대화 초기화',
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close, color: softBrownColor, size: 20),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 16),

          // 메시지 목록
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: _messages.length + (_isTyping ? 1 : 0),
              itemBuilder: (context, i) {
                if (_isTyping && i == _messages.length) {
                  return _buildTyping();
                }
                final msg = _messages[i];
                final isUser = msg.role == 'user';
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if (!isUser) ...[
                        Container(
                          width: 30, height: 30,
                          margin: const EdgeInsets.only(right: 6),
                          decoration: const BoxDecoration(color: primaryColor, shape: BoxShape.circle),
                          child: const Icon(Icons.restaurant, color: Colors.white, size: 16),
                        ),
                      ],
                      Flexible(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: isUser ? primaryColor : creamColor,
                            borderRadius: BorderRadius.only(
                              topLeft: const Radius.circular(18),
                              topRight: const Radius.circular(18),
                              bottomLeft: Radius.circular(isUser ? 18 : 4),
                              bottomRight: Radius.circular(isUser ? 4 : 18),
                            ),
                          ),
                          child: Text(
                            msg.text,
                            style: TextStyle(
                              fontSize: 14,
                              color: isUser ? Colors.white : darkColor,
                              height: 1.5,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),

          // 입력창
          Container(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: lightLineColor)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _inputController,
                    enabled: !_isTyping,
                    onSubmitted: _send,
                    maxLength: 300,
                    decoration: InputDecoration(
                      hintText: '먹당이에게 말 걸어보세요...',
                      hintStyle: TextStyle(color: softBrownColor.withAlpha(150), fontSize: 14),
                      filled: true,
                      fillColor: creamColor,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                      counterText: '',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => _send(_inputController.text),
                  child: Container(
                    width: 44, height: 44,
                    decoration: BoxDecoration(
                      color: _isTyping ? lightLineColor : primaryColor,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTyping() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Container(
            width: 30, height: 30,
            margin: const EdgeInsets.only(right: 6),
            decoration: const BoxDecoration(color: primaryColor, shape: BoxShape.circle),
            child: const Icon(Icons.restaurant, color: Colors.white, size: 16),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(color: creamColor, borderRadius: BorderRadius.circular(18)),
            child: const Text('...', style: TextStyle(color: softBrownColor, fontSize: 16, letterSpacing: 3)),
          ),
        ],
      ),
    );
  }
}

class _Msg {
  const _Msg({required this.role, required this.text});
  final String role;
  final String text;
}
