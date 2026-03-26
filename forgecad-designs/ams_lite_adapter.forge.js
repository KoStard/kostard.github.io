// AMS Lite Spool Adapter (74.5mm to 55mm)
// Features compressible arms and snap-fit teeth

// --- Parameters ---
const od = param("Adapter OD", 74.0, { min: 60, max: 90, unit: "mm" }); // Spool bore is 74.5mm, 0.5mm clearance
const id = param("Adapter ID", 55, { min: 40, max: 70, unit: "mm" });
const h = param("Spool Depth", 60, { min: 30, max: 100, unit: "mm" });

const numArms = param("Number of Arms", 2, { min: 2, max: 6, step: 1 });

const flangeOd = param("Flange OD", 85, { min: 75, max: 110, unit: "mm" });
const flangeThick = param("Flange Thick", 2, { min: 1, max: 5, step: 0.5, unit: "mm" });

// Cutout dimensions (determines arm flexibility)
const cutBaseW = param("Cut Bottom Width", 50, { min: 20, max: 80, unit: "mm" });
const cutTopW = param("Cut Top Width", 8, { min: 2, max: 40, unit: "mm" });
const ringH = param("Base Ring Height", 4, { min: 1, max: 20, unit: "mm" });

// Snap-fit teeth
const toothW = param("Tooth Width", 10, { min: 5, max: 20, unit: "mm" });
const toothP = param("Tooth Protrusion", 1.5, { min: 0.5, max: 5, step: 0.1, unit: "mm" });
const toothH = param("Tooth Height", 2, { min: 1, max: 12, unit: "mm" });

// --- Main Body ---
// Create the main cylindrical tube and the bottom flange
// Total height = flangeThick + spool depth, so the adapter reaches the full spool depth
const totalH = flangeThick + h;
const baseCyl = circle2d(od / 2).subtract(circle2d(id / 2)).extrude(totalH);
const flange = circle2d(flangeOd / 2).subtract(circle2d(id / 2)).extrude(flangeThick);

let body = union(baseCyl, flange).color('#333333');

// --- Cutouts ---
// We generate a 2D trapezoidal profile, fillet its corners to relieve stress, 
// extrude it into a solid cutter, and pattern it 3 times around the cylinder.
const zB = flangeThick + ringH;
const zT = totalH + 5; // Overshoot to ensure clean cut through the top rim

const cutPts = [
  [-cutBaseW / 2, zB],
  [cutBaseW / 2, zB],
  [cutTopW / 2, zT],
  [-cutTopW / 2, zT]
];

// Round the corners of the cut to prevent stress fractures when flexing
const fr = 3; 
const cutProfile = filletCorners(cutPts, [
  { index: 0, radius: fr },
  { index: 1, radius: fr },
  { index: 2, radius: fr },
  { index: 3, radius: fr }
]);

const cutterDepth = (od - id) / 2 + 20; // Deep enough to cut completely through the wall
const cutter = cutProfile.extrude(cutterDepth)
  .rotate(90, 0, 0) // Stand the cut profile upright
  .translate(0, od / 2 + 5, 0); // Position it to slice inward on the front wall

// Pattern the cutter evenly around the cylinder
const cutAngle = 360 / numArms;
const cutters = [];
for (let i = 0; i < numArms; i++) {
  cutters.push(cutter.clone().rotate(0, 0, cutAngle * i));
}
const cuts = union(...cutters);

// Remove the cutouts from the body to create the flexible arms
body = body.subtract(cuts);

// Fillet the straight edges along each cutout slot
// These are concave edges (inside corners where material was removed)
const topCutEdges = selectEdges(body, {
  atZ: totalH,
  perpendicular: [0, 0, 1],  // horizontal edges
  minLength: 5,               // skip tiny tessellation fragments
  convex: false,
  concave: false
});

for (const e of topCutEdges) {
  body = filletEdgeSegment(body, e, 1.5);
}

// --- Snap-Fit Teeth ---
// A box on the top surface of each arm that protrudes past the OD.
// Bottom flush with top of body (z=totalH), top at z=totalH+toothH.
// Only the part past the OD sits outside the spool bore.
const rInner = id / 2;
const rOuter = od / 2;
const toothDepth = rOuter - rInner + toothP; // From inner wall edge to past outer wall

const toothAngle = 360 / numArms;
const tooth = box(toothW, toothDepth, toothH, true)
  .translate(0, rInner + toothDepth / 2, totalH + toothH / 2)
  .rotate(0, 0, toothAngle / 2); // Center tooth on each arm

// Pattern the tooth evenly to sit on each arm
const toothParts = [];
for (let i = 0; i < numArms; i++) {
  toothParts.push(tooth.clone().rotate(0, 0, toothAngle * i));
}
const teeth = union(...toothParts);

// Final merge
body = union(body, teeth);

return body;
