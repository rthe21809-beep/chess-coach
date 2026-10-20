"""Tiny prefix-matched opening book."""
from __future__ import annotations
from typing import Optional

_RAW = [
    (("e4","e5","Nf3","Nc6","Bb5"), "Ruy Lopez"),
    (("e4","e5","Nf3","Nc6","Bc4"), "Italian Game"),
    (("e4","e5","Nf3","Nc6","d4"), "Scotch Game"),
    (("e4","e5","Nf3","Nc6","Nc3"), "Four Knights"),
    (("e4","e5","Nf3","Nf6"), "Petrov Defence"),
    (("e4","e5","Nf3","d6"), "Philidor Defence"),
    (("e4","e5","Bc4"), "Bishop Opening"),
    (("e4","e5","Nc3"), "Vienna Game"),
    (("e4","e5","f4"), "King Gambit"),
    (("e4","c5","Nf3","d6","d4"), "Sicilian Open"),
    (("e4","c5","Nf3","Nc6"), "Sicilian Old"),
    (("e4","c5","Nf3","e6"), "Sicilian Kan"),
    (("e4","c5","Nc3"), "Sicilian Closed"),
    (("e4","c5","c3"), "Sicilian Alapin"),
    (("e4","c5","d4"), "Sicilian Morra"),
    (("e4","e6"), "French Defence"),
    (("e4","c6"), "Caro-Kann"),
    (("e4","d5"), "Scandinavian"),
    (("e4","Nf6"), "Alekhine Defence"),
    (("e4","d6"), "Pirc Defence"),
    (("e4","g6"), "Modern Defence"),
    (("d4","d5","c4","e6"), "QGD"),
    (("d4","d5","c4","c6"), "Slav Defence"),
    (("d4","d5","c4","dxc4"), "QGA"),
    (("d4","d5","c4"), "Queen Gambit"),
    (("d4","Nf6","c4","g6","Nc3","Bg7"), "King Indian"),
    (("d4","Nf6","c4","e6","Nc3","Bb4"), "Nimzo-Indian"),
    (("d4","Nf6","c4","e6","Nf3","b6"), "Queen Indian"),
    (("d4","Nf6","c4","c5","d5"), "Benoni Defence"),
    (("d4","f5"), "Dutch Defence"),
    (("d4","d5","Bf4"), "London System"),
    (("d4","Nf6","Bf4"), "London System"),
    (("c4",), "English Opening"),
    (("Nf3",), "Reti Opening"),
    (("b3",), "Nimzo-Larsen"),
    (("f4",), "Bird Opening"),
    (("g3",), "Benko Opening"),
    (("b4",), "Polish Opening"),
    (("d4","d5"), "Queen Pawn Game"),
    (("e4","e5"), "Open Game"),
    (("e4",), "King Pawn"),
    (("d4",), "Queen Pawn"),
]
_TABLE = sorted(_RAW, key=lambda x: len(x[0]), reverse=True)

def opening_name(san_moves):
    for moves, name in _TABLE:
        if len(moves) <= len(san_moves) and tuple(san_moves[:len(moves)]) == moves:
            return name
    return None
