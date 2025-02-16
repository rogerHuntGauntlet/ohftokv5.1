class Director {
  final String name;
  final String style;
  final String description;

  const Director({
    required this.name,
    required this.style,
    required this.description,
  });
}

const List<Director> famousDirectors = [
  Director(
    name: "Christopher Nolan",
    style: "complex narratives with non-linear storytelling, practical effects, and IMAX cinematography",
    description: "Known for mind-bending plots, practical effects over CGI, and innovative storytelling structures.",
  ),
  Director(
    name: "Quentin Tarantino",
    style: "non-linear storytelling, stylized violence, and pop culture references",
    description: "Famous for sharp dialogue, genre-blending, and creative violence with a distinct visual style.",
  ),
  Director(
    name: "Wes Anderson",
    style: "symmetrical compositions, pastel colors, and deadpan humor",
    description: "Recognized for meticulous visual detail, quirky characters, and distinctive color palettes.",
  ),
  Director(
    name: "Martin Scorsese",
    style: "gritty realism, complex characters, and dynamic camera work",
    description: "Master of character-driven narratives, tracking shots, and intense dramatic sequences.",
  ),
  Director(
    name: "Steven Spielberg",
    style: "emotional storytelling, innovative visual effects, and sweeping camera movements",
    description: "Expert at combining spectacle with heart, known for family-friendly blockbusters and serious dramas.",
  ),
  Director(
    name: "David Fincher",
    style: "dark themes, meticulous attention to detail, and psychological complexity",
    description: "Known for perfectionism, dark narratives, and technical precision in cinematography.",
  ),
  Director(
    name: "Stanley Kubrick",
    style: "perfectionist compositions, tracking shots, and psychological depth",
    description: "Legendary for attention to detail, innovative techniques, and exploring human nature.",
  ),
  Director(
    name: "Tim Burton",
    style: "gothic fantasy, quirky characters, and dark whimsy",
    description: "Master of gothic aesthetics, combining dark themes with whimsical storytelling.",
  ),
]; 