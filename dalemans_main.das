require daslib/media

options debugger            // uncomment for debug in VS Code
require daslib/debug        // uncomment for debug in VS Code

def create_image2(width, height: int; pixels: string; palette: table<int; uint>&): Image
    var p <- [{for c in pixels; palette?[c] ?? 0u}]
    return <- create_image(width, height, p)

var gfxCarCenter <- create_image(24, 16,
        "........................" +
        "........................" +
        ".......hhhhhmmmmm......." +
        "......hggggggggggl......" +
        ".....hggggggggggggl....." +
        ".....hggggggggggggl....." +
        "....hhmmmmmmmmmmmlll...." +
        "...hmxxxxxxxxxxxxxxll..." +
        "...mxllllllllllllllxl..." +
        "...xmmmmmmmmmmmmmmmmx..." +
        "..xmrrrrmmmmmmmmrrrrlx.." +
        "..xmmmmmmmmmmmmmmmmmlx.." +
        "..xllllllllllllllllllx.." +
        "..xxllllllllllllllllxx.." +
        "..xxx..............xxx.." +
        "........................",

        {{ '.' => 0xFF00FF;
           'h' => 0xF09347;
           'm' => 0xE7812D;
           'l' => 0x995925;
           'g' => 0x162D57;
           'r' => 0xB30F0F;
           'x' => 0x000000
        }}
        )
let gfxCarPivot = 16

var gfxTree0 <- create_image(24, 16,
        "........................" +
        "........xhhhhhl........." +
        "......xhhhhhmmmmll......" +
        "....xhhmhhmmhhmmmmll...." +
        "...xhhmhhhmhmmmhhmmml..." +
        "...xhmmhhmlmhmhmmlmml..." +
        "...xhhhhmlmhmmmmmlmlx..." +
        "...xhhhmhmmhmmhmlmmlx..." +
        "...xhhhmhmhmlhmmmmllx..." +
        "....xxhhmhmlmlhmlllxx..." +
        "......xlmmmmlmmllx......" +
        "..........xxxx.........." +
        "..........xxxx.........." +
        "..........xxxx.........." +
        ".........xxxxxxx........" +
        ".......xxxxxxxxxx.......",

        {{ '.' => 0x10ff00ff;
           'h' => 0x33A747;
           'm' => 0x235A3C;
           'l' => 0x173625;
           'x' => 0x000000
        }}
        )
let gfxTree0Pivot = 16


var gfxPillar <- create_image(24, 16,
        "........................" +
        "........................" +
        "........................" +
        "........................" +
        "........................" +
        "........................" +
        ".........hhhhhh........." +
        "........hxxxxxxl........" +
        "........hxxxxxxl........" +
        "........hhhxxlll........" +
        "........hxxxxxxl........" +
        "........hxxxxxxl........" +
        "........hhhxxlll........" +
        "........hxxxxxxl........" +
        "........hxxxxxxl........" +
        "........................",

        {{ '.' => 0xff00ff;
           'x' => 0x808080;
           'l' => 0x202020;
           'h' => 0xFFFFFF
        }}
        )
let gfxPillarPivot = 16

//track coordinate system:
//XZ surface plane, origin = TL; Y is height

struct RoadSplineNode
    pos    : float3
    lside  : float
    rside  : float
    object : uint

struct RoadNode
    pos    : float3
    lside  : float
    rside  : float
    object : uint
    colour : int

struct RoadVisNode
    pos     : float3
    lside   : float
    rside   : float
    object  : uint
    colour   : int

struct Level
    size : uint
    nodes : array<RoadNode>

struct Camera
    heading : float2
    pos     : float3
    track_position : float
    offset : float
    offset_accel : float
    nearest_node : int

enum GameMode
    OnStart
    RaceStart
    RaceGoing
    Win
    Lose

var game_mode = GameMode RaceGoing
var race_time = 0.0
// car state
var car_velocity = 0.0
var car_steering = 0.0
var car_accel = 0.0
var car_steering_accel = 0.0
var k_car_max_speed = 1.33
var k_car_accel_max = 0.3
var k_car_brake_max = 0.5
var k_steering_accel_max = 0.5
var k_throttle_accel = 1.0
var k_throttle_brake = 3.0
var k_steering_accel = 0.001
var k_steering_damping = 0.1

var track_length   = 0.0
var track_count    = 0
var track_data : array<RoadNode>
var track_spline_data : array<RoadSplineNode>

let map_scale = 4.0 //scale spline coords
let map_size = 1000

var camera : Camera

let near_plane = 2.0
let road_segment_length = 1.0

let scr_wdt = get_screen_width()
let scr_hgt = get_screen_height()
let scr_wdtf = float(get_screen_width())
let scr_hgtf = float(get_screen_height())

def reset_game()
    camera.heading = float2(0.,1.)
    camera.nearest_node = 0;
    camera.offset = 7.0
    camera.offset_accel = 1.0
    camera.pos = track_data[0].pos
    camera.pos.y = camera.pos.y + 5.0

    //camera.pos = float3(0., 5., 0.)

    camera.track_position = 0.0

def prepare_width()
    return 

let road_border_width = 0.2
let roadtex = [[uint[20]
                0x2EA00C; 0xFF0000;0x747272;0xFF0000;0x2EA00C;
                0x329115; 0xFFFFFF;0x4B4B4B;0xFFFFFF;0x329115;
                0x000000; 0x000000;0x747272;0x000000;0x000000;
                0x000000; 0xFFFFFF;0x4B4B4B;0xffffff;0x000000
            ]]


def apply_fog(colour : uint; scale : float) : uint
    var b: uint = (colour >> uint(0)) & 0xff
    var g: uint = (colour >> uint(8)) & 0xff
    var r: uint = (colour >> uint(16)) & 0xff

    let dist = near_plane / scale
    var coeff = min(1.0, dist / 400.);
    coeff = pow(coeff, 8.0)
    let fog_color = float3(float(0x30)/255.,
                           float(0x5f)/255.,
                           float(0x9c)/255.)

    var rf: float = lerp(float(r)/255., fog_color.x, coeff);
    var gf: float = lerp(float(g)/255., fog_color.y, coeff);
    var bf: float = lerp(float(b)/255., fog_color.z, coeff);

    return make_color(rf,gf,bf,1.0)

def draw_sprite(y0, y1 :int; sx0, sx1 : float; scale0, scale1 : float; vn : RoadVisNode&)
    let scr_halfx = scr_wdtf / 2.0
    let sc0 = scale0 * scr_halfx
    let sc1 = scale1 * scr_halfx

    let rx00 = float(scr_halfx + sc0 * (sx0 - vn.lside - road_border_width * 6.0))
    let rx03 = float(scr_halfx + sc0 * (sx0 + vn.rside + road_border_width * 6.0))

    //text_out(100, 120, "vn {rx00} {rx03} {y0}", 0xffffff)

    if (vn.object & 0x0100) != 0x0
        let wdt = scale0 * float(gfxPillar.width) *20.
        let hgt = scale0 * float(gfxPillar.height)*50.
        gfxPillar |> draw_image(rx00-wdt, float(y0) - hgt,0xffffffff, float2(wdt, hgt))

    if (vn.object & 0x0001) != 0x0
        let wdt = scale0 * float(gfxPillar.width) *20.
        let hgt = scale0 * float(gfxPillar.height)*50.
        gfxPillar |> draw_image(rx03, float(y0) - hgt,0xffffffff, float2(wdt, hgt))

    if (vn.object & 0x0200) != 0x0
        let wdt = scale0 * float(gfxTree0.width) *50.
        let hgt = scale0 * float(gfxTree0.height)*150.
        gfxTree0 |> draw_image(rx00-wdt, float(y0) - hgt,0xffffffff, float2(wdt, hgt))

    if (vn.object & 0x0002) != 0x0
        let wdt = scale0 * float(gfxTree0.width) *50.
        let hgt = scale0 * float(gfxTree0.height)*150.
        gfxTree0 |> draw_image(rx03, float(y0) - hgt,0xffffffff, float2(wdt, hgt))

def draw_car_sprite()
    var scale0 = near_plane / (15.0)
    let sx0 = scale0
    let sy0 = - camera.offset * scale0
    let sy0i = int((scr_hgtf/-2.0 * sy0) + scr_hgtf/2.0)
    let scr_halfx = scr_wdtf / 2.0
    let sc0 = scale0 * scr_halfx

    let rx00 = float(scr_halfx + sc0 * (sx0))

    let wdt = scale0 * float(gfxCarCenter.width) *50.
    let hgt = scale0 * float(gfxCarCenter.height)*50.
    //gfxCarCenter |> draw_image(100., 100.0,0xffffffff, float2(wdt, hgt))
    gfxCarCenter |> draw_image(rx00 - wdt/2.0, float(sy0i) - hgt,0xffffffff, float2(wdt, hgt))


def draw_line(y0, y1 :int; sx0, sx1 : float; scale0, scale1 : float; vn : RoadVisNode&)
    let scr_halfx = scr_wdtf / 2.0
    let sc0 = scale0 * scr_halfx
    let sc1 = scale1 * scr_halfx

    let rx00 = float(scr_halfx + sc0 * (sx0 - vn.lside - road_border_width))
    let rx01 = float(scr_halfx + sc0 * (sx0 - vn.lside))
    let rx02 = float(scr_halfx + sc0 * (sx0 + vn.rside))
    let rx03 = float(scr_halfx + sc0 * (sx0 + vn.rside + road_border_width))
    let rx10 = float(scr_halfx + sc1 * (sx1 - vn.lside - road_border_width))
    let rx11 = float(scr_halfx + sc1 * (sx1 - vn.lside))
    let rx12 = float(scr_halfx + sc1 * (sx1 + vn.rside))
    let rx13 = float(scr_halfx + sc1 * (sx1 + vn.rside + road_border_width))

    let off = 4096.0
    //left side
    var poly0 : array<float2>
    poly0 |> push(float2(-off, float(y0)))
    poly0 |> push(float2(rx00, float(y0)))
    poly0 |> push(float2(rx10, float(y1)))
    poly0 |> push(float2(-off, float(y1)))

    //left border
    var poly1 : array<float2>
    poly1 |> push(float2(rx00, float(y0)))
    poly1 |> push(float2(rx01, float(y0)))
    poly1 |> push(float2(rx11, float(y1)))
    poly1 |> push(float2(rx10, float(y1)))

    //center
    var poly2 : array<float2>
    poly2 |> push(float2(rx01, float(y0)))
    poly2 |> push(float2(rx02, float(y0)))
    poly2 |> push(float2(rx12, float(y1)))
    poly2 |> push(float2(rx11, float(y1)))

    //right border
    var poly3 : array<float2>
    poly3 |> push(float2(rx02, float(y0)))
    poly3 |> push(float2(rx03, float(y0)))
    poly3 |> push(float2(rx13, float(y1)))
    poly3 |> push(float2(rx12, float(y1)))

    //right side
    var poly4 : array<float2>
    poly4 |> push(float2(rx03, float(y0)))
    poly4 |> push(float2(rx03+off, float(y0)))
    poly4 |> push(float2(rx13+off, float(y1)))
    poly4 |> push(float2(rx13, float(y1)))

    fill_convex_polygon(poly0, apply_fog(roadtex[vn.colour * 5 + 0], scale0))
    fill_convex_polygon(poly1, apply_fog(roadtex[vn.colour * 5 + 1], scale0))
    fill_convex_polygon(poly2, apply_fog(roadtex[vn.colour * 5 + 2], scale0))
    fill_convex_polygon(poly3, apply_fog(roadtex[vn.colour * 5 + 3], scale0))
    fill_convex_polygon(poly4, apply_fog(roadtex[vn.colour * 5 + 4], scale0))
    return

def push_spline(x, y, z: int; lside, rside : float; obj_mask : uint)
    var rn : RoadSplineNode;
    rn.pos = float3(map_scale * float(x), float(z), map_scale * float(map_size - y))
    rn.lside = lside
    rn.rside = rside
    rn.object = obj_mask
    track_spline_data |> push(rn)

def lerpx(a, b; k : float)
    return a + ((b-a) * k );

def draw_spline4(p0, p1, p2, p3: float2)
    let sc = 0.2 / map_scale
    let ox = scr_wdt / 8
    let oy = scr_hgt / 8 + int(float(map_size)*sc * map_scale)
    for i in range(0, 100)
        let ii = float(i)/100.
        var pa = lerp(p0, p1, ii)
        var pb = lerp(p1, p2, ii)
        var pc = lerp(p2, p3, ii)
        var px = lerp(pa, pb, ii)
        var py = lerp(pb, pc, ii)
        var pt = lerp(px, py, ii)
        //set_pixel(scr_wdt / 2 + int(px.x)/20 , scr_hgt / 2 + int(px.y)/20,0x00ff00);
        //set_pixel(scr_wdt / 2 + int(py.x)/20 , scr_hgt / 2 + int(py.y)/20,0x0000ff);
        set_pixel(ox + int(pt.x*sc) , oy - int(pt.y*sc),0xc0c0c0);

def draw_spline3(p0, p1, p2, p3: float2)
    let ox = scr_wdt / 8
    let oy = scr_hgt / 8
    let sc = 0.2 / map_scale
    for i in range(0, 1000)
        let ii = float(i)/1000.
        var pa = lerp(p0, p1, ii)
        var pb = lerp(p1, p2, ii)
        var pt = lerp(pa, pb, ii)
        //set_pixel(scr_wdt / 2 + int(pa.x)/20 , scr_hgt / 2 + int(pa.y)/20,0x00ff00);
        //set_pixel(scr_wdt / 2 + int(pb.x)/20 , scr_hgt / 2 + int(pb.y)/20,0x0000ff);
        set_pixel(ox + int(pt.x*sc) , oy + int(pt.y*sc),0xff0000);

def draw_map
    var count = track_spline_data |> length()
    let sc = 0.2 / map_scale
    let ox = scr_wdt / 8
    let oy = scr_hgt / 8 + int(float(map_size)*sc * map_scale)

    //spline control points
    /*
    for i in range(0, count)
        set_pixel(ox + int(track_spline_data[i].pos.x * sc),
                  oy - int(track_spline_data[i].pos.z * sc), 0xffff00)
*/
    //draw map
    //for i in range(0, 1)
    for i in range(0, count / 4)
        let ii = 4 * i
        draw_spline4(track_spline_data[(ii+0)%count].pos.xz,
                    track_spline_data[(ii+1)%count].pos.xz,
                    track_spline_data[(ii+2)%count].pos.xz,
                    track_spline_data[(ii+3)%count].pos.xz)
    fill_circle(ox + int(camera.pos.x * sc),
                oy - int(camera.pos.z * sc), 4, 0xCA7936)
    fill_circle(ox + int(camera.pos.x * sc),
                oy - int(camera.pos.z * sc), 3, 0x004040)

def draw_hud()
    set_font_size(30)
    let velocity = int(car_velocity * 50. * 3600. / 1000.)
    text_out(930, 120, "Speed {velocity} km/h", 0xffffff)
    let minutes = int(race_time / 60.0)
    let seconds = int(race_time % 60.0)
    text_out(930, 150, "Time  {minutes}:{seconds}", 0xffffff)

//generated track_data
def gen_spline4(id0, id1, id2, id3 : int; var oldnode : RoadNode&; var index : int&)
    var sd0 = track_spline_data[id0]
    var sd1 = track_spline_data[id1]
    var sd2 = track_spline_data[id2]
    var sd3 = track_spline_data[id3]

    var p0 = sd0.pos
    var p1 = sd1.pos
    var p2 = sd2.pos
    var p3 = sd3.pos

    let road_segment_length_sq = road_segment_length * road_segment_length   

    for i in range(0, 1000)
        let ii = float(i)/1000.0
        var pa = lerp(p0, p1, ii)
        var pb = lerp(p1, p2, ii)
        var pc = lerp(p2, p3, ii)
        var px = lerp(pa, pb, ii)
        var py = lerp(pb, pc, ii)
        var pt = lerp(px, py, ii)

        let dist : float = distance_sq(pt, oldnode.pos)
        if dist > road_segment_length_sq || index == 0
            var rn : RoadNode 
            rn.pos = pt 
            rn.lside = lerp((sd1.lside), (oldnode.lside), ii)
            rn.rside = lerp((sd1.rside), (oldnode.rside), ii)
            if index >= 12 && index < 16
                rn.colour = ((index >> 2) & 1) + 2 
            else
                //grass
                rn.colour = ((index >> 2) & 1) + 0

            var mask = 0x0
            if (sd0.object & 0x001) != 0x0 //pillar
                if ((index - 0) & 31) == 0
                    mask |= 0x001
            if (sd0.object & 0x100) != 0x0 //pillar
                if ((index - 0) & 31) == 0
                    mask |= 0x100
            if (sd0.object & 0x002) != 0x0 //tree
                if (index & 31) == 16
                    mask |= 0x002
            if (sd0.object & 0x200) != 0x0 //tree
                if (index & 31) == 16
                    mask |= 0x200
            rn.object = mask

            index += 1
            track_data |> push(rn)
            oldnode = rn

def build_track()
    //create spline track outline on 1000x1000 map
    //spline has origin in TL
    //segments has orgin in BL
    let lwd = 4.
    let rwd = 4.
    let lwd3 = 4.
    let rwd3 = 4.
    //debug spling segment sraight up
    
    /*
    push_spline(150, 200, 0, lwd, rwd, 0x0707);
    push_spline(150, 150, 0, lwd, rwd, 0x0707);  //ctrl
    push_spline(150, 120, 0, lwd, rwd, 0x0707);  //ctrl
    push_spline(150, 100, 0, lwd, rwd, 0x0707);
*/
    //track splines
    push_spline(150, 200, 0, lwd3, rwd, 0x0303);
    push_spline(150, 200, 00, lwd3, rwd, 0x0303);  //ctrl
    push_spline(600, 100, 20, lwd3, rwd, 0x0303);  //ctrl
    push_spline(600, 100, 0, lwd, rwd,  0x0303);

    push_spline(600, 100, 0, lwd, rwd, 0x0101);
    push_spline(800, 100, 0, lwd, rwd, 0x0101);  //ctrl
    push_spline(800, 200, 0, lwd, rwd, 0x0101);  //ctrl
    push_spline(600, 250, 0, lwd, rwd, 0x0101);

    push_spline(600, 250, 0, lwd, rwd, 0x0303);
    push_spline(400, 300, 0, lwd, rwd, 0x0303);  //ctrl
    push_spline(400, 500, 0, lwd, rwd, 0x0303);  //ctrl
    push_spline(500, 500, 0, lwd, rwd, 0x0303);

    push_spline(500, 500, 0, lwd, rwd, 0x0101);
    push_spline(800, 500, 0, lwd, rwd, 0x0101);
    push_spline(800, 750, 0, lwd, rwd, 0x0101);
    push_spline(500, 800, 0, lwd, rwd, 0x0101);

    push_spline(500, 800, 0, lwd, rwd, 0x0101);
    push_spline(300, 720, 0, lwd, rwd, 0x0101);
    push_spline(600, 600, 0, lwd, rwd, 0x0101);
    push_spline(300, 600, 0, lwd, rwd, 0x0101);

    push_spline(300, 600, 0, lwd, rwd, 0x0101);
    push_spline(100, 550, 0, lwd, rwd, 0x0303);
    push_spline(000, 300, 0, lwd, rwd, 0x0303);
    push_spline(150, 200, 0, lwd, rwd, 0x0101);

    var count = track_spline_data |> length()
    var oldnode : RoadNode 
    oldnode.pos   = track_spline_data[0].pos
    oldnode.lside = track_spline_data[0].lside
    oldnode.rside = track_spline_data[0].rside

    var track_data_index = 0

    //for i in range(0, 1)
    for i in range(0, count / 4)
        let ii = 4 * i
        gen_spline4((ii+0) % count, (ii+1) % count, (ii+2) % count, (ii+3) % count, oldnode, track_data_index)
        
    track_count = track_data_index
    track_length = float(track_data_index) * road_segment_length

def distance2d(a, b : float2) : float
    return sqrt(sqr(b.x-a.x) + sqr(b.y-a.y))

def calc_prev_index(index, count : int) : int
    var prev = index - 1
    if (prev < 0)
        prev = count - 1
    return prev

def get_node_index() : int
//    if camera.track_position < 0.0
    return (int(floor(camera.track_position / road_segment_length)) + track_count) % track_count
    //return int(floor(camera.track_position / road_segment_length))

def draw_road()

    //update_node_index()
    var node_index = get_node_index() 
    let td_count = track_data |> length()

    text_out(100, 80, "heading {camera.heading.x} {camera.heading.y}", 0xffffff)

    var m0 = float2( camera.heading.x, camera.heading.y)
    var m1 = float2( camera.heading.y,-camera.heading.x)

    var vis_nodes : array<RoadVisNode>
    for i in range(0, 400)
        var vn : RoadVisNode
        var rn = track_data[(node_index + i) % td_count]
        //text_out(100, 60, "rn {rn.pos.x} {rn.pos.y} {rn.pos.z}", 0xffffff)
        var pos = rn.pos - camera.pos
        vn.pos.x = pos.x * m1.x + pos.z * m1.y;
        vn.pos.z = pos.x * m0.x + pos.z * m0.y;
        vn.pos.y = pos.y

        //transform
        vn.lside = float(rn.lside)
        vn.rside = float(rn.rside)
        vn.object = rn.object
        vn.colour = rn.colour
/*
        vn.pos.x = float(i & 1) / 5.0 - camera.pos.x
        vn.pos.y = float(i & 1) / 10. - camera.pos.y
        vn.pos.z = float(i) * 2.0     - camera.pos.z
       // vn.lside = 3.0
       // vn.rside = 3.0
        vn.colour = (i / 4) & 1
        */
        //text_out(100, 120 + i*16, "vn {vn.pos.x} {vn.pos.y} {vn.pos.z}", 0xffffff)
        push(vis_nodes, vn)

    //draw back to front
    let count = vis_nodes |> length(); 
    for i in range(0, count-2)
        var ri = count - i - 2
        let vn0 : RoadVisNode& = vis_nodes[ri+0]
        let vn1 : RoadVisNode& = vis_nodes[ri+1]
        let dist0 = vn0.pos.z
        let dist1 = vn1.pos.z 
        if dist0 > 0.1 && dist1 > 0.1
            let scale0 = near_plane / dist0
            let scale1 = near_plane / dist1
            let sy0 = vn0.pos.y * scale0
            let sy1 = vn1.pos.y * scale1
            let sy0i = int((scr_hgtf/-2.0 * sy0) + scr_hgtf/2.0)
            let sy1i = int((scr_hgtf/-2.0 * sy1) + scr_hgtf/2.0)
            if abs(sy0i - sy1i) > 0
                draw_line(sy0i, sy1i, vn0.pos.x, vn1.pos.x, scale0, scale1, vn0)
            if vn0.object != 0x0
                draw_sprite(sy0i, sy1i, vn0.pos.x, vn1.pos.x, scale0, scale1, vn0)

def prepare_gfx()
    make_image_color_transparent(gfxCarCenter, 0xff00ff)
    make_image_color_transparent(gfxTree0, 0xff00ff)
    make_image_color_transparent(gfxPillar, 0xff00ff)

// 'initialize' runs once when game starts and every hot-reload
[export]
def initialize
    set_window_title("daLeMans")

    prepare_gfx()
    build_track()
    reset_game()
    return

def camera_movement()
    camera.track_position += car_velocity

    let td_count = track_data |> length()
    var node_index = get_node_index() 
    camera.nearest_node = node_index

    let heading_num_nodes = 10
    //interpolate camera heading
    var curr_node_pos  = track_data[(node_index + 0) % td_count].pos
    var next_node_pos  = track_data[(node_index + 1) % td_count].pos
    var curr_node_look = track_data[(node_index + heading_num_nodes) % td_count].pos
    var next_node_look = track_data[(node_index + heading_num_nodes + 1) % td_count].pos
    var curr_heading_vec = normalize(curr_node_look - curr_node_pos)
    var next_heading_vec = normalize(next_node_look - next_node_pos)
    let heading_vec = lerp(curr_heading_vec, next_heading_vec, camera.track_position % road_segment_length)
    let interp_pos = lerp(curr_node_pos, next_node_pos, camera.track_position % road_segment_length)

    camera.pos = interp_pos
    camera.pos.y = interp_pos.y + camera.offset
    camera.heading = normalize(heading_vec.xz)


def car_movement()
    car_velocity += car_accel
    car_velocity = min(car_velocity, k_car_max_speed)
    //car_velocity = max(car_velocity, 0.)
    car_steering += car_steering_accel * car_velocity * 1.0;
    car_steering *= k_steering_damping



// this function is called to update game data,
// dt - time elapsed since the previous update (in seconds)
[export]
def act(dt: float)
    if get_key(VK_ESCAPE)
        schedule_quit_game()

//    if game_mode == GameMode OnStart
//        if get_key(VK_RETURN)
//            game_mode = GameMode RaceGoing

    car_accel = 0.0
    car_steering_accel = 0.0

    if game_mode == GameMode RaceStart
        race_time = 0.0
        camera.offset -= camera.offset_accel * dt
        camera.offset_accel += 20.5 * dt
        if (camera.offset <= 5.01)
            game_mode = GameMode RaceGoing
        camera.offset = max(camera.offset, 5.0)

    if game_mode == GameMode RaceGoing 
        camera.offset = 5.0
        race_time += dt;

        if get_key(VK_W)
            car_accel = k_throttle_accel * dt
            car_accel = min(car_accel, k_car_accel_max)

        if get_key(VK_S)
            car_accel = -k_throttle_brake * dt
            car_accel = max(car_accel, -k_car_brake_max)

        if get_key(VK_D)
            car_steering_accel = +1.1 * dt
            car_steering_accel = min(car_steering_accel, k_steering_accel_max)

        if get_key(VK_A)
            car_steering_accel = -1.1 * dt
            car_steering_accel = max(car_steering_accel, -k_steering_accel_max)

    camera_movement()
    car_movement()

    return

def draw_debug_info
    set_font_size(16)
    text_out(100, 0, "camera {camera.pos.x} {camera.pos.y} {camera.pos.z} {camera.track_position}", 0xffffff)
    text_out(100, 20, "camera node {camera.nearest_node} / {track_count} ", 0xffffff)
    return

// this function will be called every frame after 'act',
// you can draw anything in this function
[export]
def draw
    fill_rect(0, 0, scr_wdt, scr_hgt/1, 0x305F9C)
//    fill_rect(0, scr_hgt/2, scr_wdt, scr_hgt/2, 0x217934)

    enable_alpha_blend()
    draw_road()
    draw_car_sprite()
    //fill_rect(0, 0, scr_wdt, scr_hgt, 0xFF305F9C)
    //fill_circle(100.0,0.0, 100.0,0xff)
    //gfxCarCenter |> draw_image(scr_wdtf/2.0,500.0,0xffffffff, float2(float(gfxCarCenter.width) * 8., float(gfxCarCenter.height)*8.))
//    gfxTree0 |> draw_image(scr_wdtf/2.0-200.0,500.0,0xffffffff, float2(float(gfxTree0.width) * 4., float(gfxTree0.height)*16.))
//    gfxPillar |> draw_image(scr_wdtf/2.0+200.0,500.0,0xffffffff, float2(float(gfxPillar.width) * 4., float(gfxPillar.height)*8.))
    disable_alpha_blend()

    draw_map()
    draw_hud()

    //draw_debug_info()
    return
