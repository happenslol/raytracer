const Vec3 = @import("vec3.zig");
const Ray = @import("ray.zig");
const Interval = @import("interval.zig");
const Hittable = @import("hittable.zig");

const Self = @This();

center: Vec3,
radius: f64,

pub fn init(center: Vec3, radius: f64) Self {
    return .{ .center = center, .radius = @max(0, radius) };
}

pub fn hit(self: *const Self, r: *const Ray, ray_t: Interval, hit_record: ?*Hittable.Record) bool {
    const oc = self.center.sub(r.origin);
    const a = r.direction.lengthSquared();
    const h = r.direction.dot(&oc);
    const c = oc.lengthSquared() - self.radius * self.radius;

    // 0 or > 0 means 1 solution (tangent) or 2 solutions (intersection)
    const discriminant = h * h - a * c;

    if (discriminant < 0) {
        return false;
    }

    const discriminantSqrt = @sqrt(discriminant);

    // Find the nearest root that lies in the acceptable range.
    var root = (h - discriminantSqrt) / a;
    if (!ray_t.surrounds(root)) {
        root = (h + discriminantSqrt) / a;
        if (!ray_t.surrounds(root))
            return false;
    }

    if (hit_record) |rec| {
        rec.t = root;
        rec.p = r.at(root);
        rec.setFaceNormal(r, &rec.p.sub(self.center).divScalar(self.radius));
    }

    return true;
}
