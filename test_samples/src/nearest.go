package main

import (
	"encoding/json"
	"fmt"
	"math"
	"sort"
	"sync"
)

type Point struct {
	X, Y float64
}

func (p Point) Distance(other Point) float64 {
	dx := p.X - other.X
	dy := p.Y - other.Y
	return math.Sqrt(dx*dx + dy*dy)
}

func (p Point) String() string {
	return fmt.Sprintf("(%.2f, %.2f)", p.X, p.Y)
}

type KNearestFinder struct {
	points []Point
	mu     sync.RWMutex
}

func NewKNearestFinder() *KNearestFinder {
	return &KNearestFinder{points: make([]Point, 0)}
}

func (f *KNearestFinder) Add(p Point) {
	f.mu.Lock()
	defer f.mu.Unlock()
	f.points = append(f.points, p)
}

func (f *KNearestFinder) FindKNearest(target Point, k int) []Point {
	f.mu.RLock()
	defer f.mu.RUnlock()

	type distPoint struct {
		point Point
		dist  float64
	}
	dps := make([]distPoint, len(f.points))
	for i, p := range f.points {
		dps[i] = distPoint{point: p, dist: target.Distance(p)}
	}
	sort.Slice(dps, func(i, j int) bool { return dps[i].dist < dps[j].dist })

	result := make([]Point, 0, k)
	for i := 0; i < k && i < len(dps); i++ {
		result = append(result, dps[i].point)
	}
	return result
}

func (f *KNearestFinder) ToJSON() (string, error) {
	f.mu.RLock()
	defer f.mu.RUnlock()
	data, err := json.MarshalIndent(f.points, "", "  ")
	return string(data), err
}

func main() {
	finder := NewKNearestFinder()
	finder.Add(Point{1.0, 2.0})
	finder.Add(Point{3.0, 4.0})
	finder.Add(Point{5.0, 1.0})
	finder.Add(Point{0.5, 0.5})

	nearest := finder.FindKNearest(Point{2.0, 2.0}, 2)
	for _, p := range nearest {
		fmt.Println(p)
	}
}
