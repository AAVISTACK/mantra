// lib/features/community/data/models/room_model.dart

import 'package:flutter/material.dart';

class RoomModel {
  final String id;
  final String name;
  final String description;
  final String emoji;
  final String type;
  final int memberCount;
  final bool isMember;
  final bool isFeatured;
  final bool isWomenOnly;
  final String? latestPost;
  final Color color;

  const RoomModel({
    required this.id,
    required this.name,
    required this.description,
    required this.emoji,
    required this.type,
    required this.memberCount,
    required this.isMember,
    required this.isFeatured,
    required this.isWomenOnly,
    this.latestPost,
    required this.color,
  });

  factory RoomModel.fromJson(Map<String, dynamic> json) => RoomModel(
        id: json['id'],
        name: json['name'],
        description: json['description'],
        emoji: json['emoji'] ?? '💬',
        type: json['type'],
        memberCount: json['member_count'],
        isMember: json['is_member'] ?? false,
        isFeatured: json['is_featured'] ?? false,
        isWomenOnly: json['women_only'] ?? false,
        latestPost: json['latest_post'],
        color: Color(int.parse(
            (json['color'] ?? 'FF7A9E7E').replaceFirst('#', '0xFF'))),
      );

  // Mock data for development
  static List<RoomModel> mockRooms() => [
        RoomModel(
          id: '1',
          name: 'Bollywood Unpopular Opinions',
          description: 'Hot takes welcome. Fights expected.',
          emoji: '🎬',
          type: 'interest',
          memberCount: 1247,
          isMember: true,
          isFeatured: true,
          isWomenOnly: false,
          latestPost: '"DDLJ is overrated" — debate?',
          color: const Color(0xFFC4654A),
        ),
        RoomModel(
          id: '2',
          name: 'Desi Women Talk',
          description: 'A safe space. Vent, share, support.',
          emoji: '🌸',
          type: 'women_only',
          memberCount: 892,
          isMember: true,
          isFeatured: false,
          isWomenOnly: true,
          latestPost: 'Anyone else tired of family pressure?',
          color: const Color(0xFF7A9E7E),
        ),
        RoomModel(
          id: '3',
          name: 'First-gen Professionals',
          description: 'Corporate struggles, imposter syndrome & wins.',
          emoji: '💼',
          type: 'career',
          memberCount: 2103,
          isMember: false,
          isFeatured: true,
          isWomenOnly: false,
          latestPost: 'How to negotiate salary without guilt?',
          color: const Color(0xFF5B8DB8),
        ),
        RoomModel(
          id: '4',
          name: 'Pune Night Owls',
          description: 'For those who come alive after midnight.',
          emoji: '🌙',
          type: 'city',
          memberCount: 543,
          isMember: false,
          isFeatured: false,
          isWomenOnly: false,
          color: const Color(0xFF8B6BB1),
        ),
        RoomModel(
          id: '5',
          name: 'Reading Circle: June',
          description: 'This month: Manto ki Kahaniyan.',
          emoji: '📚',
          type: 'interest',
          memberCount: 318,
          isMember: false,
          isFeatured: true,
          isWomenOnly: false,
          latestPost: 'Chapter 3 discussion thread is live',
          color: const Color(0xFFD4884A),
        ),
        RoomModel(
          id: '6',
          name: 'Startup Founders India',
          description: 'Building in public. Failing openly. Growing together.',
          emoji: '🚀',
          type: 'career',
          memberCount: 1678,
          isMember: false,
          isFeatured: false,
          isWomenOnly: false,
          color: const Color(0xFF4CAF79),
        ),
      ];
}
