package com.copecute.mgo.client.pathfinding;

import java.awt.Point;
import java.util.*;

// xử lý tìm đường đi
public class PathFinder {
    private final int[][] mapData;
    private final int mapWidth;
    private final int mapHeight;
    
    public PathFinder(int[][] mapData, int mapWidth, int mapHeight) {
        this.mapData = mapData;
        this.mapWidth = mapWidth;
        this.mapHeight = mapHeight;
    }

    public List<Point> findPath(Point start, Point end) {
        // nếu điểm đích không thể di chuyển tới, trả về danh sách trống
        if (!canMoveTo(end.x, end.y)) return new ArrayList<>();
        
        // nếu điểm đích trùng với điểm xuất phát, không cần di chuyển  
        if (start.equals(end)) return new ArrayList<>();

        // thuật toán A* để tìm đường đi
        PriorityQueue<Node> openSet = new PriorityQueue<>();
        Set<Point> closedSet = new HashSet<>();
        Map<Point, Point> cameFrom = new HashMap<>();
        Map<Point, Integer> gScore = new HashMap<>();
        
        Node startNode = new Node(start, 0 + heuristic(start, end));
        openSet.add(startNode);
        gScore.put(start, 0);
        
        // giới hạn số bước tìm kiếm để tránh tìm quá lâu
        int maxIterations = 1000;
        int iterations = 0;
        
        while (!openSet.isEmpty() && iterations < maxIterations) {
            iterations++;
            Node current = openSet.poll();
            
            if (current.pos.equals(end)) {
                return reconstructPath(cameFrom, current.pos);
            }
            
            closedSet.add(current.pos);
            
            // xét 4 hướng di chuyển
            int[][] dirs = {{0,1}, {1,0}, {0,-1}, {-1,0}};
            for (int[] dir : dirs) {
                Point next = new Point(current.pos.x + dir[0], current.pos.y + dir[1]);
                
                if (closedSet.contains(next)) continue;
                if (!canMoveTo(next.x, next.y)) continue;
                
                int tentativeG = gScore.get(current.pos) + 1;
                
                if (!gScore.containsKey(next) || tentativeG < gScore.get(next)) {
                    cameFrom.put(next, current.pos);
                    gScore.put(next, tentativeG);
                    openSet.add(new Node(next, tentativeG + heuristic(next, end)));
                }
            }
        }
        
        return new ArrayList<>();
    }

    private boolean canMoveTo(int x, int y) {
        return x >= 0 && x < mapWidth && y >= 0 && y < mapHeight && mapData[y][x] == 0;
    }

    private int heuristic(Point a, Point b) {
        return Math.abs(a.x - b.x) + Math.abs(a.y - b.y);
    }

    private List<Point> reconstructPath(Map<Point, Point> cameFrom, Point current) {
        List<Point> path = new ArrayList<>();
        path.add(current);
        while (cameFrom.containsKey(current)) {
            current = cameFrom.get(current);
            path.add(0, current);
        }
        path.remove(0); // bỏ vị trí hiện tại
        return path;
    }

    private static class Node implements Comparable<Node> {
        Point pos;
        int f;
        
        Node(Point pos, int f) {
            this.pos = pos;
            this.f = f;
        }
        
        @Override
        public int compareTo(Node other) {
            return Integer.compare(f, other.f);
        }
    }
}