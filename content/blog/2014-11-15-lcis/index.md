+++
title = "Longest Common Increasing Sequence"
aliases = ["2014/11/15/lcis/"]
template = "blog/single.html"
[taxonomies]
tags = [
  "Tutorials",
  "Rust",
  "UVic",
]
+++

A really 'cute' problem popped up in our Data Structures & Algorithms homework and I wanted to write about it.

> If you're in the class this will obviously ruin the fun, so read it later, after you're done!

<!-- more -->

The goal is to find the longest common increasing subsequence. Some notes:

* A **subsequence** of $$ s $$ is a set $$ v $$ such that $$ v \subset s $$, and the items in $$ v $$ appear in the same order as they appear in $$ s $$.
* An **increasing subsequence** of $$ s $$ is a subsequence $$ v $$ such that:

$$
  v_1 < v_2 < ... < v_n
$$

The problem calls for some $$ s $$ and some \\( t \\), returning the longest subsequence common between the sets. It is described roughly in [this link](http://www.codechef.com/problems/C5/) and a sample solution is described in a following [blog post](http://blog.codechef.com/2009/05/19/211/).

Defining $$ LCIS(s_{1}...s_{n},t_{1}...t_{m},last) $$ recursively:

* If $$ s_{n} = t_{m} $$ and $$ s_{n} > last $$, then

$$
LCIS = max(
    LCIS(s_{1}...s_{n-1},t_{1}...t_{m-1},s_{n})+1,
    LCIS(s_{1}...s_{n-1},t_{1}...t_{m},last),
    LCIS(s_{1}...s_{n},t_{1}...t_{m-1},last)
)
$$


* If \\( s\_{n}\neq t\_{m} \\), then

$$
LCIS=max(
    LCIS(s\_{1}...s\_{n-1},t\_{1}...t\_{m},last),
    LCIS(s\_{1}...s\_{n},t\_{1}...t\_{m-1},last)
)
$$

Which is fine and dandy, but it's a super slow recurrence. Think about how many times $$ LCIS(s\_1...s\_2, t\_1...t\_2) $$ will be invoked.

Instead, we'll use *Dynamic Programming*, which is much less exciting then it sounds. (I don't know about you, but I expect some serious magic, like lasers, from that kind of name.)

The basic idea of dynamic programming is to define an **optimal substructure** and discover **overlapping subproblems**. Then, we compute the value of the overlapping subproblems in a **bottom up fashion**, usually via a table or a set of vectors.

The recurrence we defined above is an **optimal substructure** since it will allow us to utilize overlapping calls. (Like $$ LCIS(s\_1...s\_2, t\_1...t\_2) $$)

Examining the problem closely, It's possible to solve this problem using two arrays instead of a matrix. We'll use $$ c $$ which stores the length of the LCIS ending at a given element $$ i $$ and $$ p $$ which stores the previous element of the LCIS (used for reconstruction).

The Rust code below is well commented and includes a number of tests.

```rust
use std::cmp::max;
use std::collections::RingBuf;

/// Longest Common Increasing Sequence
///
/// Accepts two `Vec<int>`s and returning a `Vec<int>` Which is the LCIS.
///
/// Note: There are multiple Longest Common Increasing Sequences in most inputs.
/// For example, `[5, 3, 6, 2, 7, 1, 8]` and `[1i, 2, 3, 4, 5, 6, 7, 8, 9]` have
/// multiple valid results: `[5i, 6, 7, 8]`, `[3i, 6, 7, 8]`, ...
///
pub fn lcis(s: Vec<int>, t: Vec<int>) -> Vec<int> {
    // Convient access.
    let size = max(s.len(), t.len());
    // We'll index into the largest for returning the path.
    let (largest, smallest) = {
        if s.len() == size {
            (s, t)
        } else {
            (t, s)
        }
    };
    // Length of the LCIS ending at `i`
    let mut c = Vec::<uint>::from_elem(size, 0);
    // Index of the previous element.
    let mut p = Vec::<int>::from_elem(size, 0);

    // Outer Loop
    for i in range(0u, smallest.len()) {
        let (mut cur, mut last) = (0, -1);
        // Inner Loop
        for j in range(0u, largest.len()) {
            if smallest[i] == largest[j] && cur+1 > c[j] {
                // This LCIS larger then our current.
                c[j] = cur + 1;
                p[j] = last;
            }
            if smallest[i] > largest[j] && cur < c[j] {
                cur = c[j];
                last = j as int;
            }
        }
    }

    // Find the length and end of the sequence.
    let (mut length, mut index) = (0u, 0u);
    for i in range(0u, size) {
        if c[i] > length {
            length = c[i];
            index = i;
        }
    }

    // Find the sequence.
    let sequence = if length > 0 {
        // You can't push onto the front of a vector, this is easier.
        let mut seq = RingBuf::<int>::with_capacity(size);
        // `-1` means we're at the start of the sequence.
        while index != -1 {
            // Add to the sequence.
            seq.push_front(largest[index]);
            // Set index to the previous.
            index = p[index] as uint;
        }
        // Send it back to a vector.
        // TODO: Make this better.
        seq.iter().map(|&x| x).collect()
    } else {
        // An empty set.
        Vec::<int>::new()
    };
    sequence
}

/// Single result LCIS Test Suite
///
/// These tests we know the (only) answer to, so we can test for the answer.
#[test]
fn all() {
    let s = vec![1i, 2, 3];
    let t = vec![1i, 2, 3];
    let goal = vec![1i, 2, 3];
    let result = lcis(s, t);
    assert!(result == goal, "Goal: {}, Result: {}", goal, result);
}

#[test]
fn none() {
    let s = vec![1i, 2, 3];
    let t = vec![4i, 5, 6];
    let goal = vec![];
    let result = lcis(s, t);
    assert!(result == goal, "Goal: {}, Result: {}", goal, result);
}

#[test]
fn continuous_start() {
    let s = vec![1i, 2, 3, 4, 5, 6];
    let t = vec![1i, 2, 3];
    let goal = vec![1i, 2, 3];
    let result = lcis(s, t);
    assert!(result == goal, "Goal: {}, Result: {}", goal, result);
}

#[test]
fn reversed_sizes() {
    let s = vec![1i, 2, 3];
    let t = vec![1i, 2, 3, 4, 5, 6];
    let goal = vec![1i, 2, 3];
    let result = lcis(s, t);
    assert!(result == goal, "Goal: {}, Result: {}", goal, result);
}

#[test]
fn continuous_end() {
    let s = vec![1i, 2, 3, 4, 5, 6];
    let t = vec![4i, 5, 6, 7];
    let goal = vec![4i, 5, 6];
    let result = lcis(s, t);
    assert!(result == goal, "Goal: {}, Result: {}", goal, result);
}

#[test]
fn bidirection() {
    let s = vec![10i, 1, 9, 2, 8, 3, 7, 4, 6, 5];
    let t = vec![1i, 2, 3, 4, 5, 7, 8, 9, 10]; // Skip 5 so it's unique
    let goal = vec![1i, 2, 3, 4, 5];
    let result = lcis(s, t);
    assert!(result == goal, "Goal: {}, Result: {}", goal, result);
}

#[test]
fn example() {
    // From http://blog.codechef.com/2009/05/19/211/
    let s = vec![4i, 3, 5, 6, 7, 1, 2];
    let t = vec![1i, 2, 3, 50, 6, 4, 7];
    let goal = vec![3i, 6, 7];
    let result = lcis(s, t);
    assert!(result.len() == goal.len(), "Goal: {}, Result: {}", goal, result);
}

/// Multiple Results Test Suite
///
/// These results we know only the length of, but we can test the validity the
/// sequence.
#[cfg(test)]
fn validity_test(sequence: Vec<int>) {
    for i in range(0u, sequence.len() - 1) {
        assert!(sequence[i] < sequence[i + 1],
            "Not a valid LCIS: {}", sequence);
    }
}

#[test]
fn staggered() {
    let s = vec![5i, 3, 6, 2, 7, 1, 8];
    let t = vec![1i, 2, 3, 4, 5, 6, 7, 8, 9];
    let goal = vec![5i, 6, 7, 8];
    let result = lcis(s, t);
    assert!(result.len() == goal.len(),
    	"Goal: {}, Result: {}", goal, result);
    validity_test(result);
}
```
