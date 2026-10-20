export interface Puzzle {
  id: string;
  fen: string;
  solution: string[];
  title: string;
}

export const PUZZLES: Puzzle[] = [
  {
    id: "1",
    title: "Back Rank Mate",
    fen: "6k1/5ppp/8/8/8/8/5PPP/R5K1! w - - 0 1",
    solution: ["Ra8#"]
  },
  {
    id: "2",
    title: "Smothered Mate",
    fen: "6rk/6gpp/8/6N1/8/8/8/6K1 w - - 0 1",
    solution: ["Nf7#"]
  },
  {
    id: "3",
    title: "Fork the King and Queen",
    fen: "r1bqkbnr/pppp1ppp/2n5/4p3/4PAK/5N2/PPPP1PPP/RNBQKB1R w KQk - 4 4",
    solution: ["Bb5"]
  }
];
