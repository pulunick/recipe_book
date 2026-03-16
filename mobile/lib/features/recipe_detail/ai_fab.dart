import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_service.dart';
import '../../core/theme.dart';

class AiFab extends ConsumerStatefulWidget {
  const AiFab({super.key, required this.collectionId});
  final int collectionId;

  @override
  ConsumerState<AiFab> createState() => _AiFabState();
}

class _AiFabState extends ConsumerState<AiFab>
    with SingleTickerProviderStateMixin {
  bool _isOpen = false;
  final List<_ChatMessage> _messages = [];
  final _inputController = TextEditingController();
  final _scrollController = ScrollController();
  bool _isTyping = false;
  late final AnimationController _animController;
  late final Animation<double> _scaleAnim;

  static const _quickChips = ['재료 대체', '덜 맵게', '칼로리 계산', '보관법'];

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
    _scaleAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOutBack);
  }

  @override
  void dispose() {
    _animController.dispose();
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _toggleChat() {
    setState(() => _isOpen = !_isOpen);
    if (_isOpen) {
      _animController.forward();
      if (_messages.isEmpty) {
        _messages.add(const _ChatMessage(
          role: 'assistant',
          text: '안녕하세요! 🍳 이 레시피에 대해 궁금한 점이 있으면 뭐든지 물어보세요.',
        ));
      }
    } else {
      _animController.reverse();
    }
  }

  Future<void> _send(String text) async {
    final msg = text.trim();
    if (msg.isEmpty || _isTyping) return;
    _inputController.clear();

    setState(() {
      _messages.add(_ChatMessage(role: 'user', text: msg));
      _isTyping = true;
    });
    _scrollToBottom();

    try {
      final history = _messages
          .where((m) => m.role != 'assistant' || _messages.indexOf(m) < _messages.length - 1)
          .take(_messages.length - 1)
          .map((m) => {'role': m.role, 'content': m.text})
          .toList();

      final reply = await ref
          .read(apiServiceProvider)
          .aiChat(widget.collectionId, msg, history);

      if (!mounted) return;
      setState(() {
        _messages.add(_ChatMessage(role: 'assistant', text: reply));
        _isTyping = false;
      });
    } catch (e) {
      if (!mounted) return;
      final errMsg = e.toString().contains('429')
          ? '질문 횟수를 초과했어요. 잠시 후 다시 시도해주세요.'
          : '오류가 발생했어요. 다시 시도해주세요.';
      setState(() {
        _messages.add(_ChatMessage(role: 'assistant', text: errMsg));
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

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.bottomRight,
      children: [
        // 채팅 패널
        if (_isOpen)
          ScaleTransition(
            scale: _scaleAnim,
            alignment: Alignment.bottomRight,
            child: _ChatPanel(
              messages: _messages,
              isTyping: _isTyping,
              scrollController: _scrollController,
              inputController: _inputController,
              quickChips: _quickChips,
              onSend: _send,
              onClose: _toggleChat,
            ),
          ),
        // FAB
        if (!_isOpen)
          FloatingActionButton(
            onPressed: _toggleChat,
            backgroundColor: primaryColor,
            elevation: 4,
            child: const Icon(Icons.auto_awesome, color: Colors.white),
          ),
        if (_isOpen)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: FloatingActionButton.small(
              onPressed: _toggleChat,
              backgroundColor: softBrownColor,
              elevation: 2,
              child: const Icon(Icons.close, color: Colors.white, size: 18),
            ),
          ),
      ],
    );
  }
}

class _ChatPanel extends StatelessWidget {
  const _ChatPanel({
    required this.messages,
    required this.isTyping,
    required this.scrollController,
    required this.inputController,
    required this.quickChips,
    required this.onSend,
    required this.onClose,
  });

  final List<_ChatMessage> messages;
  final bool isTyping;
  final ScrollController scrollController;
  final TextEditingController inputController;
  final List<String> quickChips;
  final void Function(String) onSend;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: MediaQuery.of(context).size.width - 32,
      height: 380,
      margin: const EdgeInsets.only(bottom: 64),
      decoration: BoxDecoration(
        color: paperColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(25),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // 헤더
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
            decoration: const BoxDecoration(
              color: primaryColor,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Row(
              children: [
                const Icon(Icons.auto_awesome, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                const Text(
                  'AI 요리 도우미',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: onClose,
                  child: const Icon(Icons.expand_more, color: Colors.white),
                ),
              ],
            ),
          ),

          // 메시지 목록
          Expanded(
            child: ListView.builder(
              controller: scrollController,
              padding: const EdgeInsets.all(12),
              itemCount: messages.length + (isTyping ? 1 : 0),
              itemBuilder: (context, i) {
                if (isTyping && i == messages.length) {
                  return const _TypingIndicator();
                }
                return _MessageBubble(message: messages[i]);
              },
            ),
          ),

          // 빠른 질문 칩
          if (!isTyping)
            SizedBox(
              height: 36,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: quickChips.length,
                separatorBuilder: (context, i) => const SizedBox(width: 6),
                itemBuilder: (context, i) => ActionChip(
                  label: Text(quickChips[i], style: const TextStyle(fontSize: 12, color: primaryColor)),
                  backgroundColor: primaryColor.withAlpha(20),
                  side: BorderSide.none,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  onPressed: () => onSend(quickChips[i]),
                ),
              ),
            ),

          // 입력창
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: inputController,
                    enabled: !isTyping,
                    onSubmitted: onSend,
                    decoration: InputDecoration(
                      hintText: '질문을 입력하세요...',
                      hintStyle: TextStyle(color: softBrownColor.withAlpha(150), fontSize: 13),
                      filled: true,
                      fillColor: creamColor,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      isDense: true,
                    ),
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => onSend(inputController.text),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: const BoxDecoration(color: primaryColor, shape: BoxShape.circle),
                    child: const Icon(Icons.send_rounded, color: Colors.white, size: 18),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message});
  final _ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == 'user';
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            Container(
              width: 28, height: 28,
              margin: const EdgeInsets.only(right: 6, top: 2),
              decoration: const BoxDecoration(color: primaryColor, shape: BoxShape.circle),
              child: const Icon(Icons.auto_awesome, color: Colors.white, size: 14),
            ),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isUser ? primaryColor : creamColor,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isUser ? 16 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 16),
                ),
              ),
              child: Text(
                message.text,
                style: TextStyle(
                  fontSize: 13,
                  color: isUser ? Colors.white : darkColor,
                  height: 1.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TypingIndicator extends StatelessWidget {
  const _TypingIndicator();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 28, height: 28,
          margin: const EdgeInsets.only(right: 6, top: 2),
          decoration: const BoxDecoration(color: primaryColor, shape: BoxShape.circle),
          child: const Icon(Icons.auto_awesome, color: Colors.white, size: 14),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(color: creamColor, borderRadius: BorderRadius.circular(16)),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _Dot(delay: 0),
              SizedBox(width: 4),
              _Dot(delay: 150),
              SizedBox(width: 4),
              _Dot(delay: 300),
            ],
          ),
        ),
      ],
    );
  }
}

class _Dot extends StatefulWidget {
  const _Dot({required this.delay});
  final int delay;

  @override
  State<_Dot> createState() => _DotState();
}

class _DotState extends State<_Dot> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 600))
      ..repeat(reverse: true);
    Future.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) _ctrl.forward();
    });
    _anim = Tween<double>(begin: 0.4, end: 1.0).animate(_ctrl);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _anim,
      child: Container(
        width: 6, height: 6,
        decoration: const BoxDecoration(color: softBrownColor, shape: BoxShape.circle),
      ),
    );
  }
}

class _ChatMessage {
  const _ChatMessage({required this.role, required this.text});
  final String role;
  final String text;
}
