package com.goodstore;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.SecureRandom;
import java.time.LocalDateTime;
import java.util.Base64;
import java.util.List;
import java.util.Map;
import javax.crypto.SecretKeyFactory;
import javax.crypto.spec.PBEKeySpec;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpSession;
import org.springframework.http.HttpStatus;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.support.GeneratedKeyHolder;
import org.springframework.jdbc.support.KeyHolder;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.server.ResponseStatusException;

@RestController
@RequestMapping("/api")
public class StoreController {
    private final JdbcTemplate db;
    private final SecureRandom random = new SecureRandom();
    public StoreController(JdbcTemplate db) { this.db = db; }

    private ResponseStatusException bad(String message) { return new ResponseStatusException(HttpStatus.BAD_REQUEST, message); }
    private String required(Map<String, Object> data, String key, int max) {
        String value = String.valueOf(data.getOrDefault(key, "")).trim();
        if (value.isEmpty() || value.length() > max || value.equals("null")) throw bad("Invalid " + key);
        return value;
    }
    private int positive(Map<String, Object> data, String key) {
        try { int value = Integer.parseInt(required(data, key, 10)); if (value <= 0) throw bad("Invalid " + key); return value; }
        catch (NumberFormatException e) { throw bad("Invalid " + key); }
    }
    private String hash(String password, byte[] salt) {
        try { PBEKeySpec spec = new PBEKeySpec(password.toCharArray(), salt, 210000, 256); return Base64.getEncoder().encodeToString(SecretKeyFactory.getInstance("PBKDF2WithHmacSHA256").generateSecret(spec).getEncoded()); }
        catch (Exception e) { throw new IllegalStateException(e); }
    }
    private String newHash(String password) { byte[] salt = new byte[16]; random.nextBytes(salt); return Base64.getEncoder().encodeToString(salt) + ":" + hash(password, salt); }
    private boolean verify(String password, String stored) {
        try { String[] parts = stored.split(":"); return MessageDigest.isEqual(hash(password, Base64.getDecoder().decode(parts[0])).getBytes(StandardCharsets.UTF_8), parts[1].getBytes(StandardCharsets.UTF_8)); }
        catch (Exception e) { return false; }
    }
    private long insert(String sql, Object... values) {
        KeyHolder key = new GeneratedKeyHolder();
        db.update(connection -> { var statement = connection.prepareStatement(sql, new String[]{"id"}); for (int i = 0; i < values.length; i++) statement.setObject(i + 1, values[i]); return statement; }, key);
        return key.getKey().longValue();
    }
    private long shop(HttpSession session) {
        Object id = session.getAttribute("shopId");
        if (!(id instanceof Long)) throw new ResponseStatusException(HttpStatus.UNAUTHORIZED, "Please sign in");
        return (Long) id;
    }
    @PostMapping("/register") @Transactional
    public Map<String, Object> register(@RequestBody Map<String, Object> input, HttpServletRequest request) {
        String name = required(input, "shopName", 150), email = required(input, "email", 254).toLowerCase(), password = required(input, "password", 128);
        if (!email.matches("^[^\\s@]+@[^\\s@]+\\.[^\\s@]+$") || password.length() < 10) throw bad("Enter a valid email and a password of at least 10 characters");
        if (!db.queryForList("SELECT id FROM gs_owners WHERE email = ?", email).isEmpty()) throw new ResponseStatusException(HttpStatus.CONFLICT, "Email already registered");
        long id = insert("INSERT INTO gs_shops(name) VALUES (?)", name);
        insert("INSERT INTO gs_owners(shop_id,email,password_hash) VALUES (?,?,?)", id, email, newHash(password));
        request.getSession().invalidate(); request.getSession(true).setAttribute("shopId", id);
        return Map.of("shopName", name);
    }
    @PostMapping("/login")
    public Map<String, Object> login(@RequestBody Map<String, Object> input, HttpServletRequest request) {
        String email = required(input, "email", 254).toLowerCase(), password = required(input, "password", 128);
        List<Map<String, Object>> rows = db.queryForList("SELECT o.shop_id, o.password_hash, s.name FROM gs_owners o JOIN gs_shops s ON s.id=o.shop_id WHERE o.email=?", email);
        if (rows.isEmpty() || !verify(password, (String) rows.get(0).get("password_hash"))) throw new ResponseStatusException(HttpStatus.UNAUTHORIZED, "Incorrect email or password");
        request.getSession().invalidate(); request.getSession(true).setAttribute("shopId", ((Number) rows.get(0).get("shop_id")).longValue());
        return Map.of("shopName", rows.get(0).get("name"));
    }
    @PostMapping("/logout") public Map<String, Boolean> logout(HttpSession session) { session.invalidate(); return Map.of("ok", true); }
    @GetMapping("/owner/me") public Map<String, Object> me(HttpSession session) { return Map.of("shopName", db.queryForObject("SELECT name FROM gs_shops WHERE id=?", String.class, shop(session))); }
    @GetMapping("/items") public List<Map<String, Object>> items() { return db.queryForList("SELECT id, name, quantity, original_price AS originalPrice, sale_price AS salePrice, deadline, sold_out AS soldOut, CONCAT('/api/items/',id,'/image') AS photo FROM gs_items WHERE deleted=FALSE AND deadline>NOW() ORDER BY id DESC"); }
    @GetMapping("/owner/items") public List<Map<String, Object>> ownerItems(HttpSession session) { return db.queryForList("SELECT id, name, quantity, original_price AS originalPrice, sale_price AS salePrice, deadline, sold_out AS soldOut, CONCAT('/api/items/',id,'/image') AS photo FROM gs_items WHERE shop_id=? AND deleted=FALSE ORDER BY id DESC", shop(session)); }
    @GetMapping(value="/items/{id}/image", produces="image/jpeg") public byte[] image(@PathVariable long id) { List<byte[]> rows = db.query("SELECT image FROM gs_items WHERE id=? AND deleted=FALSE", (rs, n) -> rs.getBytes(1), id); if (rows.isEmpty() || rows.get(0)==null) throw new ResponseStatusException(HttpStatus.NOT_FOUND); return rows.get(0); }
    private byte[] photo(Map<String, Object> input) {
        String value = required(input, "photo", 4500000);
        if (!value.startsWith("data:image/jpeg;base64,")) throw bad("Please upload a JPEG image");
        try { byte[] bytes = Base64.getDecoder().decode(value.substring(value.indexOf(',')+1)); if (bytes.length < 3 || bytes.length > 3000000 || bytes[0] != (byte)0xff || bytes[1] != (byte)0xd8) throw bad("Invalid photo"); return bytes; }
        catch (IllegalArgumentException e) { throw bad("Invalid photo"); }
    }
    private LocalDateTime deadline(Map<String, Object> input) { try { LocalDateTime value=LocalDateTime.parse(required(input,"deadline",30)); if (!value.isAfter(LocalDateTime.now())) throw bad("Deadline must be in the future"); return value; } catch (java.time.format.DateTimeParseException e) { throw bad("Invalid deadline"); } }
    @PostMapping("/owner/items") public Map<String, Object> add(@RequestBody Map<String, Object> input, HttpSession session) {
        long shopId=shop(session); String name=required(input,"name",150); int quantity=positive(input,"quantity"), original=positive(input,"originalPrice"), sale=positive(input,"salePrice"); if(sale>original) throw bad("Sale price exceeds original price");
        long id=insert("INSERT INTO gs_items(shop_id,name,quantity,original_price,sale_price,deadline,image) VALUES (?,?,?,?,?,?,?)",shopId,name,quantity,original,sale,deadline(input),photo(input)); return Map.of("id",id);
    }
    @PutMapping("/owner/items/{id}") public Map<String, Boolean> update(@PathVariable long id, @RequestBody Map<String,Object> input, HttpSession session) {
        long sid=shop(session); String name=required(input,"name",150); int quantity; try { quantity=Integer.parseInt(required(input,"quantity",10)); } catch (NumberFormatException e) { throw bad("Invalid quantity"); } if(quantity<0) throw bad("Invalid quantity"); int original=positive(input,"originalPrice"), sale=positive(input,"salePrice"); if(sale>original) throw bad("Sale price exceeds original price"); LocalDateTime until=deadline(input);
        int count = db.update("UPDATE gs_items SET name=?,quantity=?,original_price=?,sale_price=?,deadline=?,sold_out=? WHERE id=? AND shop_id=? AND deleted=FALSE",name,quantity,original,sale,until,Boolean.TRUE.equals(input.get("soldOut")),id,sid);
        if(count==0) throw new ResponseStatusException(HttpStatus.NOT_FOUND); if(input.containsKey("photo")) db.update("UPDATE gs_items SET image=? WHERE id=? AND shop_id=?",photo(input),id,sid); return Map.of("ok",true);
    }
    @DeleteMapping("/owner/items/{id}") public Map<String, Boolean> delete(@PathVariable long id,HttpSession session) { if(db.update("UPDATE gs_items SET deleted=TRUE WHERE id=? AND shop_id=?",id,shop(session))==0) throw new ResponseStatusException(HttpStatus.NOT_FOUND); return Map.of("ok",true); }
    @PostMapping("/bookings") @Transactional public Map<String, Object> book(@RequestBody Map<String,Object> input,HttpSession session) {
        long id=positive(input,"itemId"); int qty=positive(input,"quantity"); String name=required(input,"customerName",150), email=required(input,"customerEmail",254), phone=required(input,"customerPhone",40);
        if(!email.matches("^[^\\s@]+@[^\\s@]+\\.[^\\s@]+$")) throw bad("Invalid email");
        var rows=db.queryForList("SELECT sale_price FROM gs_items WHERE id=? AND deleted=FALSE AND sold_out=FALSE AND deadline>NOW() AND quantity>=? FOR UPDATE",id,qty); if(rows.isEmpty()) throw new ResponseStatusException(HttpStatus.CONFLICT,"Item unavailable or insufficient quantity");
        String token=(String)session.getAttribute("customerToken"); if(token==null) { byte[] bytes=new byte[32]; random.nextBytes(bytes); token=Base64.getUrlEncoder().withoutPadding().encodeToString(bytes); session.setAttribute("customerToken",token); }
        int price=((Number)rows.get(0).get("sale_price")).intValue(); db.update("UPDATE gs_items SET quantity=quantity-? WHERE id=?",qty,id); long bookingId=insert("INSERT INTO gs_bookings(item_id,customer_token,customer_name,customer_email,customer_phone,quantity,unit_price) VALUES (?,?,?,?,?,?,?)",id,token,name,email,phone,qty,price); return Map.of("id",bookingId,"totalPrice",price*qty);
    }
    @GetMapping("/owner/bookings") public List<Map<String,Object>> ownerBookings(HttpSession session) { return db.queryForList("SELECT b.id,b.customer_name AS customerName,i.name AS productName,b.quantity,b.quantity*b.unit_price AS totalPrice,b.status,b.created_at AS reservedAt FROM gs_bookings b JOIN gs_items i ON b.item_id=i.id WHERE i.shop_id=? ORDER BY b.id DESC",shop(session)); }
    @PostMapping("/owner/bookings/{id}/pickup") public Map<String, Boolean> pickup(@PathVariable long id,HttpSession session) { if(db.update("UPDATE gs_bookings b JOIN gs_items i ON b.item_id=i.id SET b.status='PICKED_UP' WHERE b.id=? AND i.shop_id=?",id,shop(session))==0) throw new ResponseStatusException(HttpStatus.NOT_FOUND); return Map.of("ok",true); }
    @GetMapping("/my-bookings") public List<Map<String,Object>> myBookings(HttpSession session) { String token=(String)session.getAttribute("customerToken"); if(token==null) return List.of(); return db.queryForList("SELECT b.id,i.name AS foodName,b.quantity,b.unit_price AS salePrice,b.quantity*b.unit_price AS totalPrice,b.status,b.created_at AS bookedAt FROM gs_bookings b JOIN gs_items i ON b.item_id=i.id WHERE b.customer_token=? ORDER BY b.id DESC",token); }
}
